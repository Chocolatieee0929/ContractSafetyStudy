//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {Solution, GatekeeperTwo} from "../src/level/GateKeepper.sol";

contract SolutionScript is Script {
    address contractAdd = 0x001Eb81254D32D74Da961e8370779Ba6bAF2dD14;
    Solution solution;
    // GatekeeperOne gatekeeperOne;

    function run() external {
        vm.startBroadcast();

        // solution = Solution(0xB2b8A44FBf0beDC5A43B5B42B69Af3DF761F0eE9);
        // gatekeeperOne = new GatekeeperOne();
        solution = new Solution(address(contractAdd));
        // address entrant = GatekeeperTwo(contractAdd).entrant();
        // console2.log(entrant);
        // assert(0x3F3cFa84D3825185C897cC6FCaac35431169Dc2F == entrant);
        // uint256 initial_gas = 41211;
        // uint256 gas = 575;
        // solution.numAttack(initial_gas);
        // console2.log(gas);
        // solution.numAttack(gas);
    }
}
