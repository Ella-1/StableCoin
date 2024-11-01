// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DecentralizedStableCoin} from "./DecentrilisedStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
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
    // Errors
    error DSCEngine__MoreThanZero();
    error DSCEngine__TokenPriceFeedsAndPriceFeedsNotTheSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    // State Variables
    address[] private s_collateralToken();

    mapping(address => address priceFeeds) private s_pricefeeds; //token to price feeds

    // maps each user to the token they are using and amount
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposits;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    // Events
    event ColleteralDeposited(address indexed user, address indexed token, uint256 amount);
    DecentralizedStableCoin private immutable i_dsc;
    // Modifiers

    modifier MoreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MoreThanZero();
        }
        _;
    }

    modifier isTokenAllowed(address token) {
        if (s_pricefeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    // Functions
    constructor(address[] memory tokenAddresses, address[] memory priceFeedsAddesses, address dscAddress) {
        if (tokenAddresses.length != priceFeedsAddesses.length) {
            revert DSCEngine__TokenPriceFeedsAndPriceFeedsNotTheSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_pricefeeds[tokenAddresses[i]] = priceFeedsAddesses[i];
            s_collateralDeposits.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }
    // External Functions

    function depositeCollateralAndMIntDSC() external {}

    /*
    *@notice follows CEI(chat effects Interaction)
    *@param tokenColleteralAddress the address of the token to deposit as collateral
    *@param  amountColleteral the amount of the colleteral to deposit
    * 
    */
    function depositeColleterall(address tokenColleteralAddress, uint256 amountColleteral)
        external
        MoreThanZero(amountColleteral)
        isTokenAllowed(tokenColleteralAddress)
        nonReentrant
    {
        s_collateralDeposits[msg.sender][tokenColleteralAddress] += amountColleteral;
        emit ColleteralDeposited(msg.sender,tokenColleteralAddress, amountColleteral);
        bool success = IERC20(tokenColleteralAddress).transferFrom(msg.sender, address(this), amountColleteral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemeCollwtweraForDsc() external {}

    function redeemeColleteral() external {}



    /*
    *@notice follows CEI(chat effects Interaction)
    *@param tokenColleteralAddress amount of decentrilsed stable coin to mint
    * They must havr more colleteral value than minimum treshold
    * 
    */
    function mintDsc(uint256 amountDscToMint) external MoreThanZero(amountDscToMint) {
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they minted too muct ($150 DSC, $100 ETH)
         revertIFHealthFactorIsBroken();
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    // Private and Internal functions
    function _getAccountInformation(address user) private view returns (uint256 totalDSCMinted, uint256 colleteralValueInUsd) {
        // get the amount of the total DSC minted
        totalDSCMinted = s_DSCMinted[user];
        // colleteral value in usd
        colleteralValueInUsd = getAccountCollateralValue(user);
    }

    /*
    *
    * Returns how close to liquidition a user is
    * if a user gets below 1. then they can get liquidated
    */
    function _healthFactor(address user)  private view returns (uint256) {
        // Total DSC minted
        //  Total colleteral value
        (uint256 totalDSCMinted, uint256 colleteralValueInUsd) = _getAccountInformation(user);

    }

    function _revertIFHealthFactorIsBroken(address user) internal view {
        // check health factor(Do they have enough colleteral)
        // revert if they dont

    }

    // Public and external Functions
    function getAccountCollateralValue(address user) public view returns(uint256){
        // loop through each colleteral token, get the amount they have deposited and map it to
        // the price to get the usd value
        for(uint256 i =0; i<=s_collateralDeposits.length; i++){
            address token = s_collateralDeposits
        }
    }

}
