// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {
    }

    // Deposit Ether to get WETH
    function deposit() public payable {
        require(msg.value > 0, "Must send Ether to deposit");
        _mint(msg.sender, msg.value);
    }

    // Withdraw Ether by burning WETH
    function withdraw(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient WETH balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    // Fallback function to accept Ether
    receive() external payable {
        deposit();
    }

}
