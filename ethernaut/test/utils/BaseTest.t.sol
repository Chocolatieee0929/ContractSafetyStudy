// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {Test} from "forge-std/Test.sol";

abstract contract BaseTest is Test {
    address internal deployer;
    address internal contractAddress;
    string internal mnemonic;

    function setUp() public virtual {

        deployer = vm.remeberKey(vm.envUint("PRIVATE_KEY"));
        vm.label(deployer, "Deployer");
        
        uint256 forkId = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        vm.selectFork(forkId);
    }

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }
}
