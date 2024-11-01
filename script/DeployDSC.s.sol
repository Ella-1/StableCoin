// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin }from "../src/DecentrilisedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract DeployDSc is  Script {
    function run external returns(DecentralizedStableCoin,DSCEngine) {

    }
}