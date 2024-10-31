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

    mapping(address => address priceFeeds) private s_pricefeeds; //token to price feeds

    // maps each user to the token they are using and amount
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposits;

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

    function mintDsc(uint256 amountDscToMint) external MoreThanZero(amountDscToMint) {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
