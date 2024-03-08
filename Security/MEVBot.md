# MEVBot 事件分析

通过破解 ethernaut-Switch，我对 Calldata 编码有了初步的理解，现实生活中也有利用 calldata 进行攻击的事件，我将跟随[教程](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/academy/onchain_debug/04_write_your_own_poc/readme.md)分析 MEV Bot (BNB48) 攻击事件，这个攻击总体来说并不复杂，我会将分析思路详细地记录下来，同时使用 foundry 框架进行测试。

# 攻击过程分析

## 基本信息

- 可参考的链接：[phalcon](https://phalcon.blocksec.com/tx/bsc/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2?line=2)
- 攻击基本信息

  ```
  @KeyInfo - Total Lost : ~36,044 US$
  Attack Tx: https://bscscan.com/tx/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2
  Attacker Address(EOA): 0xee286554f8b315f0560a15b6f085ddad616d0601
  Attack Contract Address: 0x5cb11ce550a2e6c24ebfc8df86c5757b596e69c1
  Vulnerable Address: 0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d (mev)
  Total Loss: ~ $140 000
  ```

- 文档中代币数量以 10\*\*18 为单位

## 攻击过程

首先，我一开始想通过`cast run 0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2 --quick --rpc-url https://rpc.ankr.com/bsc` 来追踪函数，出现报错，报错信息如下，该 rpc 节点不是归档节点，在此节点上无法找到交易信息，在网络检索后，未找到 bsc 归档节点，后续找着了会再更新。

```
2024-03-08T04:06:25.766109Z ERROR foundry_evm_core::fork::init: It looks like you're trying to fork from an older block with a non-archive node which is not supported. Please try to change your RPC url to an archive node if the issue persists.
- Error:
Could not instantiate forked environment with fork url: https://rpc.ankr.com/bsc
```

我们选择通过使用 [phalcon](https://phalcon.blocksec.com/explorer/tx/bsc/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2) 来查看攻击交易的函数调用，![MEVBot(BNB484)-call-1](<./picture/MEVBot(BNB484)-call-1.png>)
发现调用了 6 次`pancakeCall`，分别是 BSC-USD、WBNB、BUSD、USDC、BTCB、ETH，我们对其中一次进行展开，可以发现在调用`pancakeCall(_sender,_amount0,_amount1,_data)`时都进行了转账，向 Attacker Address 赚了\_amount0 数额的代币，我们找着了漏洞存在 Vulnerable Address 的`pancakeCall`函数里。
我们在[BscScan](https://bscscan.com/address/0x64dd59d6c7f09dc05b472ce5cb961b6e10106e1d#code)查看受害合约，发现未开源，使用反编译工具解析 Dedaub 解析被攻击合约，解析出来的没有`pancakeCall`，在`function_selector`这块看到了 pancakeCall 的函数选择器，我发现最后都会执行一个 0x10a 的函数，我采取了和教程一样的步骤，暂时未找到反编译结果不一样是由什么导致的。
![MEVBot(BNB484)-dedaub](<Security/picture/MEVBot(BNB484)-dedaub.png>)
![MEVBot(BNB484)-dedaub](<Security/picture/MEVBot(BNB484)-function_selector.png>)
以下是教程里边所解析出的`pancakeCall`函数， 可以看到该函数并未对 msg.ender 进行校验，任何人都能调用,
```
function pancakeCall(address varg0, uint256 varg1, uint256 varg2， bytes varg3) public nonPayable {
    require(msg.data.length-4>=128);
    require(varg0 == varg0);
    require(varg3<= 0xffffffffffffffff);
    require(4 + varg3 + 31< msg.data.length);
    require(varg3.length<= xffffffffffffffff);
    require(4 + varg3 + varg3.length + 32<= msg.data.length);
    v0 = new bytes[](varg3.length);
    CALLDATACOPY(v0.data, varg3.data, varg3.length);
    v0[varg3.length] = 0;
@>  0x10a(v0, varg2, varg1);
}
```
1. 该函数接受四个参数：address varg0, uint256 varg1, uint256 varg2， bytes varg3（附加数据），根据 Pancake协议对`pancakeCall`的定义，我们可以推断出这几个参数分别代表_sender（发送者地址）、_amount0 和 _amount1（两种代币的数量）、_data（附加数据）
2. require 语句用于检查传入的参数是否符合某些条件，主要是检查msg.data和varg3 是否符合特定的长度要求。
3. 通过CALLDATACOPY函数将 varg3 复制到一个新的bytes数组 v0 中，并将数组中的最后一个字节设置为0。
4. 调用0x10a函数，该函数接收三个参数：bytes varg0, uint256 varg1, uint256 varg2。

接下来我们看看函数 0x10a的实现，以下由这三个`transfer`函数，后两个函数的地址比较难控制，第一个 transfer 很可能存在漏洞，
```
function 0x10a(bytes varg0, uint256 varg1, uint256 varg2) private {
    require(varg0.data + varg0.length - varg0.data >= 96);
    require(MEM[varg0.data] == address(MEM[varg0.data]));
    v0 = v1 = varg0[64];
    if (0 == varg2) {
        v2, /* address */ v3 = msg.sender.token1().gas(msg.gas);
        require(bool(v2), 0, RETURNDATASIZE()); // checks call status, propagates error data on error
        require(MEM[64] + RETURNDATASIZE() - MEM[64] >= 32);
        require(v3 == address(v3));
    } else {
        v4, /* address */ v3 = msg.sender.token0().gas(msg.gas);
        require(bool(v4), 0, RETURNDATASIZE()); // checks call status, propagates error data on error
        require(MEM[64] + RETURNDATASIZE() - MEM[64] >= 32);
        require(v3 == address(v3));
    }
    if (varg2) {
    }
--> v5, /* bool */ v6 = address(v3).transfer(address(MEM[varg0.data]), varg1).gas(msg.gas);
    ...
--> v36, /* bool */ v37 = address(v34).transfer(msg.sender, varg0[32][32]).gas(msg.gas);
    require(bool(v36), 0, RETURNDATASIZE()); // checks call status, propagates error data on error
    require(MEM[64] + RETURNDATASIZE() - MEM[64] >= 32);
    require(v37 == bool(v37));
    v38 = _SafeSub(v1, varg0[32][32]);
--> v39, /* bool */ v40 = address(v34).transfer(address(this), v38).gas(msg.gas);
    require(bool(v39), 0, RETURNDATASIZE()); // checks call status, propagates error data on error
    require(MEM[64] + RETURNDATASIZE() - MEM[64] >= 32);
    require(v40 == bool(v40));
    return ;
}
```
我们可以看到，`v4, /* address */ v3 = msg.sender.token0().gas(msg.gas);`此时msg.sender对应的是攻击合约，攻击合约需要实现token0()，`v5, /* bool */ v6 = address(v3).transfer(address(MEM[varg0.data]), varg1).gas(msg.gas);`的收款地址是通过读取`MEM[varg0.data]`获得的，而 varg0.data 的值是通过在`pancakeCall(address varg0, uint256 varg1, uint256 varg2， bytes varg3)`中的 varg3 复制得到的，这也就是说，我们可以通过调用`pancakeCall`在 varg3 输入攻击者地址来控制转账。
这是攻击合约的calldata信息，调用 cast pretty calldata 输出结果如下：
```
Possible methods:
 - pancakeCall(address,uint256,uint256,bytes)
 - reservePresaleListIn(bytes)
 ------------
 [000]: 0000000000000000000000005cb11ce550a2e6c24ebfc8df86c5757b596e69c1 // varg0
 [020]: 00000000000000000000000000000000000000000000057cbe656f5e0c7507f9 // varg1
 [040]: 0000000000000000000000000000000000000000000000000000000000000000 // varg2
 [060]: 0000000000000000000000000000000000000000000000000000000000000080 // varg3的偏移
 [080]: 0000000000000000000000000000000000000000000000000000000000000060 // varg3的长度
 [0a0]: 000000000000000000000000ee286554f8b315f0560a15b6f085ddad616d0601 // varg3
 [0c0]: 0000000000000000000000000000000000000000000000000000000000000000
 [0e0]: 0000000000000000000000000000000000000000000000000000000000000000
```
我们可以看到，攻击合约调用的 `pancakeCall` 时，将攻击账户EOA的地址作为参数3传入了。

## PoC
对此次攻击复现，PoC如下：
```

```