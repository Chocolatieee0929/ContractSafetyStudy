# 绕过EOA账户检查
## 以太坊账户类型
以太坊中存在着两种账户类型，分别是EOA账户，以及合约账户。
- EOA账户
  EOA 代表“外部拥有账户”，它是一种由私钥控制且不与智能合约关联的以太坊账户。EOA 由个人用户创建，用于持有和管理以太坊资金，以及与以太坊网络上的智能合约和其他去中心化应用程序进行交互。
- 合约账户
  合约账户与智能合约相关联，并由智能合约的代码控制，通过将智能合约部署到以太坊网络来创建的。
## 区分账户类型
以太坊白皮书介绍了[以太坊账户](https://ethereum.org/en/whitepaper/#ethereum-accounts)，可以看到以太坊账户包含四个字段：
1. 随机数，用于确保每笔交易只能处理一次的计数器
2. 账户的当前以太币余额
3. 账户的合约代码（如果存在）
4. 帐户的存储根（默认为空）
只要是合约账户，就一定会包含合约代码，EOA账户则不会，合约代码长度一定为0。

## openzepplin `Address.isContract(address)`
根据这一特性，早期判断账户类型是通过读取账户地址，判断其 excodesize 是否大于 0。包括openzepplin早期3.4版本实现的[isContract(address)](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/93438eca0bdde2b023aafa803c86ccf50a2f0c2c/contracts/utils/Address.sol#L26-L35)也是通过这一原理。
```
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
```
我们不经疑问，这真的是准确的吗？早在 2021年，[ArmorFi](https://medium.com/immunefi/fei-protocol-flashloan-vulnerability-postmortem-7c5dc001affb)被发现存在漏洞，该漏洞主要是通过 闪电贷价格操纵 来实现攻击，该协议试图通过`Address.isContract`和`nonContract`修饰符来防止用户在调用`allocate()`时对价格进行操纵，此漏洞证明这种保护措施没有用。攻击者在构造合约时调用了`allocate()`，绕过了 Contract 检查。
```
contract Allocator {
    constructor(IBondingCurve bondingCurve) public {
        // We run this call from a constructor
        // to bypass the non-contract check of `allocate()`
        bondingCurve.allocate();
    }
}
```
在现在[openzepplin doc](https://docs.openzeppelin.com/contracts/2.x/api/utils#Address)有关 `Address.isContract` 的描述中，它明确指出，当返回为 0 时，存在这4种情况：
1. EOA帐户
2. a contract in construction
3. an address where a contract will be created
4. 被销毁的合约
   这表明，在某些情况下，extcodesize 指令可能无法检测到正在构建中的合约或者已经被销毁的合约，接下来我们对合约部署和销毁的流程进行探究，以便了解后面三中的情况。
## 合约的部署与销毁
首先让我们理解 State，State 是指存储在区块链上的所有账户的当前状态，包括它们的余额、合约代码、合约数据等信息。
- stateObject：管理一个账户所有信息修改的结构体，包含的是上述所说的账户信息；
- stateDB：内部用一个巨大的map 结构来管理所有stateObject，它是一个巨大的map结构，key是地址，value是stateObject，账户任何信息发生变化，会首先缓存到 StateDB 里的临时state0bject里，再有 StateDB 一起提交到底层数据库，其作用是管理和维护区块链上所有账户的状态信息，并提供对这些信息的读写操作。
### 合约的部署
总的来说，部署合约就是 EVM 通过调用 Create() 函数会创建一个新的合约地址，并且将合约代码存储在合约地址中；
- 首先，在区块链上产生一个新的合约地址，stateDB 中尚无与该地址相关的 Code 信息，此时合约 `size := extcodesize(account)` 为0；
- 如果合约中包含`constructor`函数，则执行`constructor`函数对合约进行初始化；
- 然后，执行 setCallCode 或类似函数，stateDB 中与该合约地址相关的 Code 信息被更新。这个函数的作用是将合约的代码存储到合约地址中，执行完这个步骤后，合约地址中存储的代码就是合约的实际代码。
- 合约的 `size := extcodesize(account)` 变为非0，表示合约地址上存储了合约代码。

### 合约的销毁
合约的销毁通常是通过 Solidity 中的 selfdestruct(address payable recipient) 函数来触发的。当执行 selfdestruct 函数时，合约账户上剩余的以太币会被发送到指定的目标地址（recipient），同时合约的存储和代码会从状态中被移除。

这意味着合约的状态数据（包括存储的数据和代码）会被清除，合约地址上的 extcodesize 将会变为 0，因为该地址上已经不再存储任何代码。

## 绕过EOA检查
综上，我们可以很清楚地了解到，在合约部署时，我们可以通过在`construct()` 函数里调用其他函数，绕过 isContract() 检查，大家可以结合[Ethernaut-GateKeeperTwo](https://github.com/Chocolatieee0929/ContractSafetyStudy/ethernaut/solution/14.GateKeeperTwo.md)进行学习，试着写写PoC来加深理解。

## 安全建议
- 通过检查 extcodesize 可以确定地址是否为合约，这存在明显漏洞，如果 extcodesize > 0，则该地址为合约；但 extcodesize = 0，则该地址可能为 EOA，也可能是正在创建状态的合约。
- 如果想要检测调用者是否为合约，可以通过 (tx.origin == msg.sender) 来进行判断。当调用者为 EOA 时，tx.origin 和 msg.sender 相等；当它们不相等时，调用者为合约。
```solidity
function isContract(address account) public view returns (bool) {
    return (tx.origin != msg.sender);
}
```