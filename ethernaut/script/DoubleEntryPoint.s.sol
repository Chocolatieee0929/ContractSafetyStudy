// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./BaseScript.s.sol";
import {console2} from "forge-std/console2.sol";

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface DelegateERC20 {
    function delegateTransfer(address to, uint256 value, address origSender) external returns (bool);
}

interface IDetectionBot {
    function handleTransaction(address user, bytes calldata msgData) external;
}

interface IForta {
    function setDetectionBot(address detectionBotAddress) external;
    function notify(address user, bytes calldata msgData) external;
    function raiseAlert(address user) external;
}

interface ICryptoVault {
    function setUnderlying(address latestToken) external;
    function sweepToken(IERC20 token) external;
}

interface ILegacyToken {
    function mint(address to, uint256 amount) external;
    function delegateToNewContract(DelegateERC20 newContract) external;
    function transfer(address to, uint256 value) external returns (bool);
}

interface IDoubleEntryPoint {
    function delegateTransfer(address to, uint256 value, address origSender) external returns (bool);
}

contract Forta is IForta {
    mapping(address => IDetectionBot) public usersDetectionBots;
    mapping(address => uint256) public botRaisedAlerts;

    function setDetectionBot(address detectionBotAddress) external override {
        usersDetectionBots[msg.sender] = IDetectionBot(detectionBotAddress);
    }

    function notify(address user, bytes calldata msgData) external override {
        if (address(usersDetectionBots[user]) == address(0)) return;
        try usersDetectionBots[user].handleTransaction(user, msgData) {
            return;
        } catch {}
    }

    function raiseAlert(address user) external override {
        if (address(usersDetectionBots[user]) != msg.sender) return;
        botRaisedAlerts[msg.sender] += 1;
    }
}

contract DetectionBot is IDetectionBot {
    address public immutable vault;
    address public immutable forta;

    constructor(address _vault, address _forta) {
        vault = _vault;
        forta = _forta;
    }

    function setDetectionBot() public {
        IForta(forta).setDetectionBot(address(this));
    }

    function handleTransaction(address user, bytes calldata msgData) external {
        (address to,, address origSender) = abi.decode(msgData[4:], (address, uint256, address));
        console2.log("to", to);
        // valut 调用DET的delegateTransfer
        if (origSender == vault) {
            IForta(forta).raiseAlert(user);
        }
    }
}

contract Solution is BaseScript {
    function run() public {
        contractAddress = 0x7f8b8260E07ca138E86634331F38a0096412C36F; // DET
        address cryptoVault = 0x3802a508C0d60CCfd0C1682646aF88d069C1bF2D;
        address lgt = 0x6354A0Cdca37C29F937Ee11443947C0B00dc2409; //LGT
        address forta = 0x46380943f224A17EDCaB86030a6F49fa5Ad3C60c;

        /* 
        vault.sweptTokensRecipient = deployer;

        legacyToken.owner is not deployer
         */

        vm.startBroadcast(deployer);
        DetectionBot bot = new DetectionBot(cryptoVault, forta);
        IForta(forta).setDetectionBot(address(bot));
        // ICryptoVault(cryptoVault).sweepToken(IERC20(lgt));
        vm.stopBroadcast();
    }
}
