// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestCoin is ERC20 {
    event Log(address a);
    constructor() ERC20("TC", "TestCoin") {
    }

    function getAddress() public view returns (address addr) {
        return address(this);
    }

    function getFreeCoins(address addr) public {
        _mint(addr, 100);
    }
}