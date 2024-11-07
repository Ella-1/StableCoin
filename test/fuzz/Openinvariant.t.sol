// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// invariant stores our property

// what are the invariants
// 1. the total suplay of dsc should be less than the total vlaue of colleteral
// 2. geteeer view functions should never revert

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSc} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentrilisedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract OpenInvariantTest is StdInvariant,Test{
    DeployDSc deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
    Handler handler;
    address weth;
    address wbtc;
    function setUp() external {
    deployer = new DeployDSc();
    (dsc, dsce, helperConfig) = deployer.run(); // Match the exact order of returned values
    (,,weth,wbtc,) = helperConfig.activeNetworkConfig();
    // targetContract(address(dsce));
    handler = new Handler(dsce,dsc);
    targetContract(address(handler));
}



    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get all the value of colleteral in the protocol
        // compare it to all the debt (dsc)
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth,totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalBtcDeposited);

        assert(wethValue+wbtcValue >= totalSupply);
    }
}