// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// handler narrows down the way we call function

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentrilisedStableCoin.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256 MAX_DEPOSITE_SIZE = type(uint96).max; //gets the max uint96 value

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc){
        dsce = _dscEngine;
        dsc = _dsc;
        address[] memory colleteralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(colleteralTokens[0]);
        wbtc = ERC20Mock(colleteralTokens[1]);
    }

    // Redeem colleteral

    function depositeColleteral(uint256 colleteralSeed, uint256 amountColleteral) public {
        ERC20Mock colleteral = _getColleteralFromSeed(colleteralSeed);
        amountColleteral = bound(amountColleteral,1,MAX_DEPOSITE_SIZE);
        vm.startPrank(msg.sender);
        colleteral.mint(msg.sender, amountColleteral);
        colleteral.approve(address(dsce), amountColleteral);
        // what ever parameter we have it is going to be randomize
        dsce.depositCollateral(address(colleteral),amountColleteral);
        vm.stopPrank();
    }

    // Helper functions
    // function were we can get a finally get a valid colleteral
    function _getColleteralFromSeed(uint256 colleteralSeed) private view returns(ERC20Mock) {
        if(colleteralSeed % 2 == 0){
            return weth;
        } 
        return wbtc;
    }

    function redeemeColleteral(uint256 colleteralSeed, uint256 amountColleteral) public {
        ERC20Mock colleteral = _getColleteralFromSeed(colleteralSeed);
        uint256 maxColleteralToRedeeme = dsce.getCollateralBalanceOfUser(address(colleteral), msg.sender);
        amountColleteral = bound(amountColleteral);
    }
}