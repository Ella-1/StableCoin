// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DecentralizedStableCoin} from "./DecentrilisedStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
 * @title DSCEngine
 * @author Zoaka Bata Bukar
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract DSCEngine is ReentrancyGuard {
    ///////////////////
    //     Errors    //
    ///////////////////

    error DSCEngine__DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLengths();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__NotMinted();
    error DSCEngine__TransferedFailed();
    error DSCEngine__HealthFactorNotOk();
    error DSCEngine__HealthFactorNotImproved();
   


    /////////////////////////
    //   State Variables   //
    /////////////////////////

    mapping(address token => address priceFeed) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // THIS MEANS 10 PERCENT

    ////////////////
    //   Events   //
    ////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralReedemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    ///////////////////
    //   Modifiers   //
    ///////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed(token);
        }
        _;
    }

    ///////////////////
    //   Functions   //
    ///////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLengths();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////////////
    //   External Functions  //
    ///////////////////////////

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
    * @param amountDscToMint: The amount of DSC you want to mint
    * You can only mint DSC if you hav enough collateral
    */

    function getTokenAmountFromUsd(address token, uint256 usdAmountInwei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return (usdAmountInwei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__NotMinted();
        }
    }

    ///////////////////////////////////////////
    //   Private & Internal View Functions   //
    ///////////////////////////////////////////

    /*
    * Returns how close to liquidation a user is
    * If a user goes below 1, then they can be liquidated.
    */

    function _burnDSC(uint256 amountDSCToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDSCToBurn; // removes the dsc minted
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDSCToBurn);
        if (!success) {
            revert DSCEngine__TransferedFailed();
        }
        i_dsc.burn(amountDSCToBurn);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _redeemCollateral(address from, address to, address tokenColleteralAddress, uint256 amountCollateral)
        private
    {
        // in order ro redeme colleteral, theit health factor should be over 1
        // we want to follow check Effects Interaction(CEI)
        // we have to check the health factor
        s_collateralDeposited[from][tokenColleteralAddress] -= amountCollateral;
        emit CollateralReedemed(from, to, tokenColleteralAddress, amountCollateral);
        // _calculateHealthFactorAfter()
        bool success = IERC20(tokenColleteralAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferedFailed();
        }
    }

    //////////////////////////////////////////
    //   Public & External View Functions   //
    //////////////////////////////////////////

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        // return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
        // return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;


    }

    function depositCollaterAndMintDsc(
        address tokenColleteralAddress,
        uint256 amountColleteral,
        uint256 amountDscToMint
    ) public {
        depositCollateral(tokenColleteralAddress, amountColleteral);
        mintDsc(amountDscToMint);
    }

    function redeemCollateralForDsc(address tokenColleteralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenColleteralAddress, amountCollateral);
        // reddem collereral already checks health factor
    }

    // DRY: Dont repete yourself
    function redeemCollateral(address tokenColleteralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenColleteralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(uint256 _amount) public moreThanZero(_amount) {}

    /*
    * @param colleteral: The erc20 colleteral adddreess to liquidate from the user
    * @param user: The user with the broken health factor i.e they have health factoer below 1
    * @param debthToCover The amount of DSC you wan t o burn to improve the user health factor
    * @notice you can get partially liquidated
    * @notice you will get a liquidation for getting user funds
    * @notice this function working assume the protocol will be roughly 200% overcollaterized in order to worl
    */
    // if someone is almost undercollateralized we will pay you to liquidate them
    function liquidate(address colleteral, address user, uint256 debthToCover)
        external
        moreThanZero(debthToCover)
        nonReentrant
    {
        // need to check the health factor of the user
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorNotOk();
        }

        // we want to burn their DSC debth
        // And take thir colleteral

        uint256 tokenAmountFromDebthCovered = getTokenAmountFromUsd(colleteral, debthToCover);
        // and we are giving them a 10% bonus
        // we should implement a feature to liquidate the event the protocol is insolvent
        // and sweep extra amount into a treasury

        uint256 bonousColleteral = (tokenAmountFromDebthCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebthCovered + bonousColleteral;
        _redeemCollateral(user, msg.sender, colleteral, totalCollateralToRedeem);
        // we need to burn dsc
        _burnDSC(debthToCover, user, msg.sender); // who ever is the one calling the liquidate will be the one paying the debth

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {}
}
