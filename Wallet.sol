// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TestCoin.sol";

contract Wallet {
    address private owner;
    // зашитий адрес для перевода комиссии
    address private feeAddress = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;
    // параметры для расчёта комисси
    uint feeBase = 1;
    uint feePercentage = 1;

    mapping (address => uint) private balances;
    // маппинг[адрес пользователя][название токена]
    mapping (address => mapping (string => uint)) private tokenBalances;
    mapping (string => IERC20) private tokenNameToContract;

    function calculateFee(uint amount) view public returns (uint fee) {
        return (amount * feePercentage / 100) + feeBase;
    }

    function setFee(uint base, uint percentage) external {
        require(msg.sender == owner, "not allowed");
        feeBase = base;
        feePercentage = percentage;
    }

    event LogDeposit(address from, uint amount, uint newBalance, uint contractBalance);
    event LogTransfer(address from, address to, uint amount, uint fee, uint newBalanceFrom, uint newBalanceTo, uint contractBalance);
    event LogWithdraw(address to, uint amount, uint fee, uint newBalance, uint contractBalance);
    event LogTokenDeposit(string name, address from, uint amount, uint newBalance);
    event LogTokenTransfer(string name, address from, address to, uint amount, uint newBalanceFrom, uint newBalanceTo);
    event LogTokenWithdraw(string name, address to, uint amount, uint newBalance);

    TestCoin private testCoin = new TestCoin();
    constructor() {
      owner = msg.sender;
      // здесь можно добавлять поддерживаемые кошельком токены
      tokenNameToContract["TC"] = IERC20(testCoin.getAddress());
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        emit LogDeposit(msg.sender, msg.value, balances[msg.sender], address(this).balance);
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit LogDeposit(msg.sender, msg.value, balances[msg.sender], address(this).balance);
    }

    bool lock = false;

    function transfer(uint amount, address to) external {
        require(!lock, "reentrancy guard");
        lock = true;
        
        uint fee = calculateFee(amount);
        require(balances[msg.sender] >= amount + fee, "not enough eth");
        balances[msg.sender] -= amount + fee;
        balances[to] += amount;
        (bool success, ) = feeAddress.call{value: fee}("");
        require(success,"transfer failed");
        emit LogTransfer(msg.sender, to, amount, fee, balances[msg.sender], balances[to], address(this).balance);
        
        lock = false;
    }

    function withdraw(uint amount) external {
        require(!lock, "reentrancy guard");
        lock = true;

        uint fee = calculateFee(amount);
        require(balances[msg.sender] >= (amount + fee), "not enough eth");
        balances[msg.sender] -= (amount + fee);
        (bool success, ) = feeAddress.call{value: fee}("");
        require(success,"transfer failed");
        (success, ) = msg.sender.call{value: amount}("");
        require(success,"transfer failed");
        emit LogWithdraw(msg.sender, amount, fee, balances[msg.sender], address(this).balance);
        
        lock = false;
    }

    function dbgGetFreeCoins() external {
        testCoin.getFreeCoins(msg.sender);
    }

    function tokenDeposit(uint amount, string calldata name) external {
        require(!tokenLock, "reentrancy guard");
        tokenLock = true;
        
        IERC20 tokenContract = tokenNameToContract[name];
        tokenBalances[msg.sender][name] += amount;
        tokenContract.transferFrom(msg.sender, address(this), amount);

        emit LogTokenDeposit(name, msg.sender, amount, tokenBalances[msg.sender][name]);
    }

    bool tokenLock = false;

    function tokenTransfer(uint amount, string calldata name, address to) external {
        require(!tokenLock, "reentrancy guard");
        tokenLock = true;
        
        require(tokenBalances[msg.sender][name] >= amount, "not enough tokens");
        tokenBalances[msg.sender][name] -= amount;
        balances[to] += amount;
        emit LogTokenTransfer(name, msg.sender, to, amount, tokenBalances[msg.sender][name], tokenBalances[to][name]);
        
        tokenLock = false;
    }

    function tokenWithdraw(uint amount, string calldata name) external {
        require(!tokenLock, "reentrancy guard");
        tokenLock = true;
        
        require(tokenBalances[msg.sender][name] >= amount, "not enough tokens");
        IERC20 tokenContract = tokenNameToContract[name];
        tokenBalances[msg.sender][name] -= amount;
        tokenContract.transferFrom(address(this), msg.sender, amount);
        emit LogTokenWithdraw(name, msg.sender, amount, tokenBalances[msg.sender][name]);
        
        tokenLock = false;
    }
}