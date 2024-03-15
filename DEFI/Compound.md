# Compound
- Compound 是一个允许用户借贷代币的智能合约。
- 用户可以将钱存入compound，并获得cToken作为回报，与银行不同的是，利息是从存入 Compound 的智能合约后开始复利计算的。
- Compound 的**贷款**是通过超额担保确立的。借贷者将代币存入 Compound 中以增加他们的 “借款能力”，如果借贷者的借款能力低于 0，他们的抵押品将被出售以偿还债务。
- 每个代币（比如 Ether、Dai、USDC）都有一个借贷市场，里面包含每个用户在这个市场里的余额，以及各笔生效的借贷交易，乃至每段时期的历史利率，等等

## 概念

- 标的资产（Underlying Token）：即借贷资产，比如 ETH、USDT、USDC、WBTC 等，目前 Compound 只开设了 14 种标的资产。
- cToken：也称为生息代币，是用户在 Compound 上存入资产的凭证。每一种标的资产都有对应的一种 cToken，比如，ETH 对应 cETH，USDT 对应 cUSDT，当用户向 Compound 存入 ETH 则会返回 cETH。取款时就可以用 cToken 换回标的资产。
- 兑换率（Exchange Rate）：cToken 与标的资产的兑换比例，比如 cETH 的兑换率为 0.02，即 1 个 cETH 可以兑换 0.02 个 ETH。兑换率会随着时间推移不断上涨，因此，持有 cToken 就等于不断生息，所以也才叫生息代币。计算公式为：exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
- 抵押因子（Collateral Factor）：每种标的资产都有一个抵押因子，代表用户抵押的资产价值对应可得到的借款的比率，即用来衡量可借额度的。取值范围 0-1，当为 0 时，表示该类资产不能作为抵押品去借贷其他资产。一般最高设为 0.75，比如 ETH，假如用户存入了 0.1 个 ETH 并开启作为抵押品，当时的 ETH 价值为 2000 美元，则可借额度为 0.1 _ 2000 _ 0.75 = 150 美元，可最多借出价值 150 美元的其他资产。

## 利率模型
### 复利算法
1. 利率不变
设初始本金 P，年利率 R，时长T（单位:年），每年复利次数 N，则到期复利金额 $A 计算公式如下：
A=P(1+ R/N)^(N*T)
2. 浮动利率
   - 定义：即每次复利计息时所使用的利率是根据市场借贷供关系决定的。
   - 计算公式：At+1 ​=At​ * (1 + Rt+1​)​​​
     - A(t+1)表示在t+1时刻的复利额
     - A(t)表示在t时刻的复利额
     - R(t+1)表示在t+1时刻的利率
  如果从 t0时刻借出本金A0，利息为R0，在t时刻需要归还本息为：At ​= A0​ * (1 + Rt1​)​​​(1 + Rt2)...(1+Rt)​
  我们都知道链上数据存储是昂贵的，我们没法将所有时刻的利率都存在下来，也没法在计算本息的时候遍历所有的利率，因此 Compound 采用了很取巧的方法**累积利率**，非常巧妙,[七哥](https://learnblockchain.cn/article/5036)举得例子非常好，跟着文章算一遍完全能懂，我这就不展开了。
3. 累积利率
   (1 + R1​)​​​(1 + R2)...(1+Rt)​(1+Rt+1)​是 *t+1* 时刻的累计利率 *Pt+1*，上述例子 At = A * *Rt* / *R0*,也就是说 计算本息时只需要知道借款和还款时的累积利率，便可计算出本息额。减去借款本金，剩余部分为借款应付利息。
   也就是说，Compoud 只需要记录 借款账户，借款金额，以及借款时的累计利率。
### 复利代码
每笔借贷触发计息，在计息时只需要存储当前的累积利率，累积利率在Compound中被称之为 BorrowIndex。Compound计息方法在合约中比较冗余，下方是简化版代码：
```
function accrueInterest(){
 	
  var currentBlockNumber = getBlockNumber(); //获取当前区块高度
  //如果上次计息时也在相同区块，则不重复计息。
  if (accrualBlockNumber == currentBlockNumber) {
      return NO_ERROR;
  }
  
  var cashPrior = getCashPrior();  //获取当前借贷池剩余现金流
  //根据现金流、总借款totalBorrows、总储备金totalReserves 从利率模型中获取区块利率
  var borrowRateOneBlock = interestRateModel.getBorrowRate(cashPrior, totalBorrows, totalReserves);  
 	// 计算从上次计息到当前时刻的区间利率
  var borrowRate=borrowRateOneBlock*(currentBlockNumber - accrualBlockNumber);
 	// 更新总借款，总借款=总借款+利息=总借款+总借款*利率=总借款*（1+利率）
  totalBorrows = totalBorrows*(1+borrowRate);
  // 更新总储备金
  totalReserves =totalReserves+ borrowRate*totalBorrows*reserveFactor;
  // 更新累积利率：  最新borrowIndex= 上一个borrowIndex*（1+borrowRate）
  borrowIndex = borrowIndex*(1+borrowRate);
  // 更新计息时间
  accrualBlockNumber=currentBlockNumber;
  return NO_ERROR;
}
```
### 利率模型
- 利率模型是 Compound 协议的核心，它定义了利率的计算方式，以及利率的区间。
- getBorrowRate() 和 getSupplyRate()，分别用来获取当前的借款利率和存款利率。但这两个利率不是年化率，也不是日利率，而是区块利率，即按**每个区块计算的利率**。
#### 直线型
  - 借款利率：计算公式为 `y = k * x + b`, y 即借款利率值，x 表示资金使用率，k 为斜率，b 则是 x 为 0 时的起点值。
   ```
   constructor(uint baseRatePerYear, uint multiplierPerYear) public {
       baseRatePerBlock = baseRatePerYear.div(blocksPerYear);
       multiplierPerBlock = multiplierPerYear.div(blocksPerYear);

       emit NewInterestParams(baseRatePerBlock, multiplierPerBlock);
   }
   ```
   构造函数有两个入参：
   1. baseRatePerYear：基准年利率，其实就是公式中的 b 值, 常量值，表示一年内的区块数 2102400，是按照每 15 秒出一个区块计算得出的。
   2. multiplierPerYear：其实就是斜率 k 值
   3. x 值即资金使用率则是动态计算的，计算公式为：
   ```
      资金使用率 = 总借款 / (资金池余额 + 总借款 - 储备金)
      utilizationRate = borrows / (cash + borrows - reserves)
   ```
  - 存款利率 和借款利率是类似的，计算公式如下：
   ```
   存款利率 = 资金使用率 * 借款利率 *（1 - 储备金率）= x * y * (1 - reserveFactor)
   supplyRate = utilizationRate * borrowRate * (1 - reserveFactor)
   ```
  - getBorrowRate() 和 getSupplyRate()的代码实现
  ```
    function getBorrowRate(uint cash, uint borrows, uint reserves) public view returns (uint) {
    uint ur = utilizationRate(cash, borrows, reserves);
    return ur.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
   }

   function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) public view returns (uint) {
    uint oneMinusReserveFactor = uint(1e18).sub(reserveFactorMantissa);
    uint borrowRate = getBorrowRate(cash, borrows, reserves);
    uint rateToPool = borrowRate.mul(oneMinusReserveFactor).div(1e18);
    return utilizationRate(cash, borrows, reserves).mul(rateToPool).div(1e18);
  }
   ```
#### 拐点型
   超过拐点之后，则利率公式将变成：y = k2*(x - p) + (k*p + b)
   - k2 表示拐点后的直线的斜率，
   - p 则表示拐点的 x 轴的值，资金使用率太高了
   - b、k、k2、p，分别对应了构造函数中的几个入参：baseRatePerYear、multiplierPerYear、jumpMultiplierPerYear、kink。
  ```
  function getBorrowRateInternal(uint cash, uint borrows, uint reserves) internal view returns (uint) {
    uint util = utilizationRate(cash, borrows, reserves);

    if (util <= kink) {
      	return util.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
    } else {
        uint normalRate = kink.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
        uint excessUtil = util.sub(kink);
        return excessUtil.mul(jumpMultiplierPerBlock).div(1e18).add(normalRate);
    }
  }

  ```
# 拓展-累计收益
> 这是我个人初步思考，还有很多不完善的地方，欢迎指正。

用户在 Compound 存款，获取的收益是 CToken ，（1）通过 cToken 的汇率赚取利息，该汇率相对于标的资产的价值增加，以及（2）获得试用 cToken 作为抵押品的能力。
也就说，在 Compoud 存款和利息(外来收入)使用的token是不一样，如果这二者是一样的呢？

考虑用户存入ETH，获得的利息是ETH，利息也能生息并且用户在任意时刻能够在不撤出本金的前提下提取收益，我们如何设计协议，如何满足这个需求呢？
## 算法思考
参考 Compound 复利算法，我设计了以下算法：
- 假设在t0，存入本金A0，
- 在t1产生手续费，对t1时刻，每股收益是p1，本金更新为A1=A0*（1+p1）
- 在t2, 手续费产生，每股收益是p2，本金更新为A2=A1*(1+p2)
- 类似地，当tn 手续费，更新完手续费后，An=An-1 *(1+pn )
- 使用累积乘可以得到，本金为An=A0*（1+p1）(1+p2)…(1+pn)

协议只需要记录 每次手续费产生记录累积费率Ei =（1+p1）(1+p2)…(1+pi)，
按照上述例子来说，t0时刻记录A0和E0，在用户提取收益时根据当前E，通过 A0*E/E0 - A0更新质押收益

## 需要完善的地方
在我的仓库有对这个算法的初步实现，后续会继续改进。
1. Ei 更新的时间，需不需要锁定期
2. 资金利用率太大怎么办，也就是 compound 里提到的，如果外来收入和存款借款是同一种token或者ETH，会带来什么安全问题，我们应当如何进行规避？

# 参考链接

1. https://learnblockchain.cn/article/2593#Compound
2. https://learnblockchain.cn/article/3158
3. https://learnblockchain.cn/article/2618