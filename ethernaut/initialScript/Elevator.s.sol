//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {Elevator} from "../src/level/Elevator.sol";
import {Building} from "../src/attack/Elevator_att.sol";

contract ElevatorScript is Script {
    address elevatorAdd = 0xb5d50DFB91e0de8C9f3909cBAbf73762037d593C;
    Building public building;

    function run() external {
        // vm.startBroadcast();

        building = new Building(elevatorAdd);
        building.go();
        // vm.stopBroadcast();
    }
}
