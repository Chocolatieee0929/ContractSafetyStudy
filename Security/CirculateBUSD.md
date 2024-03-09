# 攻击过程分析
新加坡时间2023年1月12日下午 14:22:39 ，CirculateBUSD项目跑路，损失金额227万美金。我将跟随[教程](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main/academy/onchain_debug/05_Rugpull/)分析这一事件，这个攻击总体来说并不复杂，我会将分析思路详细地记录下来，同时使用 foundry 框架进行测试。

## 基本信息

- 可参考的链接：[phalcon](https://phalcon.blocksec.com/tx/bsc/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3)
- 攻击基本信息

  ```
  @KeyInfo - Total Lost : ~ 2 270 000 US$
  Attack Tx: https://bscscan.com/tx/0x3475278b4264d4263309020060a1af28d7be02963feaf1a1e97e9830c68834b3
  Attacker Address(EOA): 0x5695Ef5f2E997B2e142B38837132a6c3Ddc463b7
  Attack Contract Address: 0xc30808d9373093fbfcec9e026457c6a9dab706a7
  Vulnerable Address: 0x9639d76092b2ae074a7e2d13ac030b4b6a0313ff

  @Analysis
  Blocksec : https://twitter.com/BlockSecTeam/status/1556483435388350464
  ```
- 文档中代币数量以 10\*\*18 为单位

## 攻击过程
首先，我们对此次攻击交易进行函数追踪，通过 [phalcon](https://phalcon.blocksec.com/explorer/tx/bsc/0x3475278b4264d4263309020060a1af28d7be02963feaf1a1e97e9830c68834b3) 来追踪函数，结果如下，
![alt text](Security/picture/CirculateBUSD.png)
整个攻击过程非常简单，Attacker 调用`CirculateBUSD.startTrading`，可以看到Attacker输入了3个参数，分别是 _trader = Attacker, _borrowAmount, _swappedToken=WBNB, 进入debug模式，不难看出`startTrading`是抵押借款的函数，该函数已开源，我们来看看，
```
    function startTrading(address _trader, uint256 _borrowAmount, address _swappedToken) public {
        require( msg.sender ==  _trader || msg.sender == AutoStartOperator, "You don't have permission" );
        if(lastStartMID[_swappedToken] != currentMinuteID())
            lastStartMBorrowAmount[_swappedToken] = 0;
        (,, uint256 MinCollateralLimit,,,uint256 DailyLoanInterestRate,,) = ISwapHelper(SwapHelper).TradingInfo( BUSDContract,_swappedToken );
        uint256 _borrowableAmount = getBorrowableAmount(_swappedToken, _trader); // 获取可借款金额
        require( _borrowAmount <= _borrowableAmount, "Over full borrowable amount limit" );
        require( debtors[_trader].collateralAmount >= MinCollateralLimit, "Cannot trade without depositing collateral funds more than MinCollateralLimit" );
        require( debtors[_trader].tradingState == false, "Trading has already started" );

        totalTradingAmount[_swappedToken] += _borrowAmount;
        lastStartMBorrowAmount[_swappedToken] += _borrowAmount;
        IERC20(BUSDContract).safeApprove(SwapHelper, _borrowAmount);
        uint256 swapOutAmount = ISwapHelper(SwapHelper).swaptoToken( BUSDContract,_swappedToken, _borrowAmount);
        debtors[_trader].tradingState = true;
        debtors[_trader].debtAmount = _borrowAmount;
        debtors[_trader].swappedAmount = swapOutAmount;
        debtors[_trader].swappedToken = _swappedToken;
        debtors[_trader].startTime = block.timestamp;
        debtors[_trader].withdrawableAmount = 0;
        addTrader(_trader);

        lastStartMID[_swappedToken] = currentMinuteID();
        unsetAutoStartTrading(_trader);

        // calculate the total profit
        if(tradeInfo[_swappedToken].startstate==false){
            tradeInfo[_swappedToken].startstate = true;
            tradeInfo[_swappedToken].lastTradeTime = block.timestamp;
        }
        tradeInfo[_swappedToken].totalTradeProfit += (tradeInfo[_swappedToken].totalTradeAmount * ( block.timestamp - tradeInfo[_swappedToken].lastTradeTime ) * DailyLoanInterestRate).div(percentRate * rewardPeriod);
        tradeInfo[_swappedToken].totalTradeAmount += _borrowAmount;
        tradeInfo[_swappedToken].lastTradeTime = block.timestamp;
    }

    function getBorrowableAmount(address _toToken, address _trader) public view returns(uint256 _amount){
        (uint256 MaxStartMLimit,,, uint256 MaxLoanLimit, uint256 MaxTotalTradingLimit,,,uint256 LoanDivCollateral) = ISwapHelper(SwapHelper).TradingInfo( BUSDContract,_toToken );
        if(lastStartMID[_toToken] != currentMinuteID())
            _amount = MaxStartMLimit;
        else
            _amount = MaxStartMLimit.sub(lastStartMBorrowAmount[_toToken]);
        if(_amount > MaxLoanLimit)
            _amount = MaxLoanLimit;
        if(MaxTotalTradingLimit > totalTradingAmount[_toToken]){
            if(_amount > MaxTotalTradingLimit - totalTradingAmount[_toToken])
                _amount = MaxTotalTradingLimit - totalTradingAmount[_toToken];
        }
        else
            _amount = 0;
        if(_amount>debtors[_trader].collateralAmount * LoanDivCollateral)
            _amount = debtors[_trader].collateralAmount * LoanDivCollateral;
        uint256 _bal = getBalance();
        if(_amount > _bal){
            _amount = _bal;
        }
    }

```
这个函数是抵押借款的，首先需要满足以下条件：
1. 检查消息发送者是否为 trader 或 AutoStartOperator，只有授权实体或者交易方可以调用函数，防止潜在的安全风险；
2. 交易者必须已经存入了等于或大于`MinCollateralLimit`的抵押资金
3. 检查`lastStartMID`是否不等于当前的分钟ID，如果是，则将`lastStartMBorrowAmount`设置为0。
4. 计算交换代币的可借金额，并检查请求的借款金额是否小于或等于可借金额，这个是通过调用`getBorrowableAmount`函数进行计算的，
   1. 从 SwapHelper 合约中获取交易信息，包括MaxStartMLimit、MaxLoanLimit、MaxTotalTradingLimit和LoanDivCollateral。
   2. 根据lastStartMID和当前分钟ID的比较结果，计算可借金额。如果lastStartMID不等于当前分钟ID，那么可借金额为MaxStartMLimit。否则，可借金额为MaxStartMLimit减去lastStartMBorrowAmount。
   3. 检查 MaxTotalTradingLimit 是否大于当前的交易金额。如果是，那么如果可借金额大于MaxTotalTradingLimit减去当前交易金额，那么可借金额将被设置为这个差值。
   4. 函数检查交易者抵押资产的贷款额度，如果可借金额大于抵押资产的贷款额度，那么可借金额将被设置为抵押资产的贷款额度。
   5. 函数检查合约余额，如果可借金额大于合约余额，那么可借金额将被设置为合约余额。
5. 如果满足条件，函数会批准交换助手合约花费借款金额，将借款金额交换为交换代币，这里是通过`ISwapHelper(SwapHelper).swaptoToken( BUSDContract,_swappedToken, _borrowAmount)`
6. 更新交易者的交易状态、债务金额、交换金额、交换代币、开始时间和可提取金额。交易者也被添加到交易者列表中。
7. 最后，`lastStartMID`被设置为当前的分钟ID，并且为交易者取消`AutoStartTrading`标志。
8. 函数还会计算自上次交易以来交换代币的总利润，并更新`tradeInfo`结构体中的总交易利润、总交易金额和上次交易时间。

看起来似乎都是正常的抵押借款流程，每一步都似乎是正常的，有什么问题呢?

在整个过程里，都是使用了`ISwapHelper(SwapHelper)`，一个是利用`TradingInfo`获取合约借款信息的来源，二是通过`swaptoToken`来转账，在bsc浏览器上查看并没有开源，我们来尝试利用深入了解一下ISwapHelper(SwapHelper)，利用[dedaub](https://app.dedaub.com/binance/address/0x112f8834cd3db8d2dded90be6ba924a88f56eb4b/decompiled)进行反编译，结果如下
```
function 0x598cd567(address varg0, address varg1) public payable { 
    require(4 + (msg.data.length - 4) - 4 >= 64);
    v0 = 0x4e0(varg1, varg0);
    require(v0, Error('unable to swap')); // 判断借款合约和代币是否合理
    v1 = v2 = stor_a;
    v3 = v4 = stor_b;
    v5 = v6 = stor_c;
    v7 = v8 = stor_d;
    v9 = v10 = stor_e;
    v11 = v12 = varg0 == stor_3_0_19;
    if (v12) {
        v11 = varg1 == _bUSDContract;
    }
    if (v11) {
        v1 = v13 = _SafeDiv(stor_a, 200);
        v3 = _SafeDiv(stor_b, 200);
        v5 = _SafeDiv(stor_c, 200);
        v7 = _SafeDiv(stor_d, 200);
        v9 = _SafeDiv(stor_e, 200);
    } 
    // 如果varg0是_bUSDContract，varg1是stor_3_0_19，将a,b,c,d,e直接返回
    // 如果varg1是_bUSDContract，判断varg0是不是stor_3_0_19，如果二者都符合，将a,b,c,d,e除以200，并返回信息
    return v1, v3, v5, v7, v9, stor_f, stor_10, stor_11;
}

function 0x4e0(address varg0, address varg1) private {  // 判断借款合约和代币是否合理
    v0 = v1 = 0;
    v2 = v3 = varg1 == _bUSDContract;
    if (v3) {
        v2 = v4 = varg0 == stor_3_0_19;
    } 
    if (v2) {
        v0 = v5 = 1;
    } // 如果varg1是_bUSDContract，判断varg0是不是stor_3_0_19，如果二者都符合，v0为真
    v6 = v7 = varg1 == stor_3_0_19;
    if (v7) {
        v6 = v8 = varg0 == _bUSDContract;
    } 
    if (v6) {
        v0 = v9 = 1;
    }// 如果varg1是stor_3_0_19，判断varg0是不是_bUSDContract，如果二者都符合，v0为真
    return v0;
}
```
一开始猜测会不会因为参数顺序写反了导致出现问题，但根据交易回显来看，参数顺序是正确的。我们接着来看一下`swaptoToken`，函数选择器是 0x63437561，这个函数是比较长的，我们首先根据`transfer`来定位看看能不能找到漏洞，
```
function 0x63437561(address varg0, address varg1, uint256 varg2) public payable { 
    require(4 + (msg.data.length - 4) - 4 >= 96);
    0x1a3d(varg2);
    require(stor_1 != 2, Error('ReentrancyGuard: reentrant call'));
    stor_1 = 2;
    v0 = 0x4e0(varg1, varg0);
    require(v0, Error('unable to swap'));
    if (varg2 != 0) {
        v1, /* uint256 */ v2 = varg0.allowance(address(this), stor_4_0_19).gas(msg.gas);
        require(bool(v1), 0, RETURNDATASIZE()); // checks call status, propagates error data on error
        MEM[64] = MEM[64] + (RETURNDATASIZE() + 31 & ~0x1f);
        require(MEM[64] + RETURNDATASIZE() - MEM[64] >= 32);
        0x1a3d(v2);
        if (v2 == 0) {
            ....
        }
        if (this.balance >= 0) { // 合约balance不为0，执行下面逻辑
            ...
                    if (varg2 != stor_7) {
                        ....
                        v43, /* uint256 */ v44 = _getSwapOut.swapExactTokensForTokens(varg2, 0, v36, msg.sender, block.timestamp, v20, varg0).gas(msg.gas);
                        ....
                    } else { // varg2 == stor_7
                        v49 = _SafeSub(_percentRate, stor_8);
                        require(!(bool(varg2) & (v49 > uint256.max / varg2)), Panic(17)); // arithmetic overflow or underflow
                        v50 = _SafeDiv(varg2 * v49, _percentRate);
                        v51 = _SafeSub(varg2, v50);
                        if (this.balance >= 0) {
                            if (varg0.code.size > 0) {
                                v52 = v53 = 0;
                                while (v52 < 68) {
                                    MEM[MEM[64] + v52] = MEM[MEM[64] + 32 + v52];
                                    v52 = v52 + 32;
                                }
                                if (v52 > 68) {
                                    MEM[MEM[64] + 68] = 0;
                                }
@ >>>                           v54, /* uint256 */ v55, /* uint256 */ v56, /* uint256 */ v57 = varg0.transfer(stor_6_0_19, v51).gas(msg.gas);
                                if (RETURNDATASIZE() == 0) {
                                    v58 = v59 = 96;
                                } else {
                                    v58 = v60 = new bytes[](RETURNDATASIZE());
                                    RETURNDATACOPY(v60.data, 0, RETURNDATASIZE());
                                }
                                ...
                            }
                        }
                    }
        }
    }
}
```
我们追踪到`transfer`函数，为了判断此函数位置是否是漏洞，我们使用 `cast storage` 读取 stor_6_0_19 的值(`uint256 stor_6_0_19; // STORAGE[0x6] bytes 0 to 19`)，
```
cast storage 0x112f8834cd3db8d2dded90be6ba924a88f56eb4b 6 --rpc-url $BSC
0x0000000000000000000000005695ef5f2e997b2e142b38837132a6c3ddc463b7
```
发现其值为`0x5695ef5f2e997b2e142b38837132a6c3ddc463b7`，也就是Attacker EOA的地址，看来出现问题的就是这。我们接着来往上看看执行到 `transfer`需要满足什么条件，如果是正常转账应该通过_getSwapOut.swapExactTokensForTokens进行转账，通过 cast storage 读取，其值为0x10ed43c718714eb63d5aa57b78b54704e256024e，在[bscScan](https://bscscan.com/address/0x10ed43c718714eb63d5aa57b78b54704e256024e#code)上可以看到这是个开源的 pancakerouter 。
如果 varg2 == stor_7 就会转到后门函数进行转账，通过 cast run 读取slot_7的值为 0x000000000000000000000000000000000000000000000000010168ada6bd50d4， 这和调用swapToken的参数不一致，我们来看看 stor_7 是否能够被修改.
```
function 0x4b2d25ef(address varg0, uint256 varg1, uint256 varg2) public payable { 
    require(4 + (msg.data.length - 4) - 4 >= 96);
    0x1a3d(varg1);
    0x1a3d(varg2);
@>> require(_owner == msg.sender, Error('Ownable: caller is not the owner'));
    stor_6_0_19 = varg0;
@>  stor_7 = varg1;
    stor_8 = varg2;
}
```
stor_7的确可以被 owner 修改，由此判断此次事件是 **项目方作恶** 。

# 安全建议
用户在投资任何项目之前，需要关注项目方的更新和公告，在实施任何更改之前，请确保项目方已经对合约进行了充分的安全审计，并发布了相应的更新和公告。
在进行安全审计时，审计员会关注：
1. 检查合约中的权限是否过大，是否存在直接影响用户资产安全的功能；
2. 项目方的合约代码是否符合安全编程的最佳实践，这包括使用最新的安全库，避免使用不安全的函数，以及进行适当的错误处理。
3. 检查合约中的权限是否过大。合约中的权限过大可能会导致项目方能够随意操作用户的资产，例如，如果合约中的某个函数是否可以无限地增加或减少用户的余额。
4. 检查合约中是否存在直接影响用户资产安全的功能。例如，如果合约中的某个函数可以允许项目方直接提取用户的资产，那么这可能会导致用户的资产受到损害。
