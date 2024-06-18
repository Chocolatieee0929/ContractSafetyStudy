// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {Script} from "forge-std/Script.sol";

abstract contract BaseTest is Script {
    address internal deployer;
    address internal contractAddress;
    string internal mnemonic;

    function setUp() public virtual {
        vm.rpcUrl(vm.envString("SEPOLIA_RPC_URL"));
        vm.label(deployer, "Deployer");
    }
}
