// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ExtendERC20 is ERC20, Ownable {
    constructor(
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) Ownable(_msgSender()) {}

    function mint(address account, uint amount) external {
        require(_msgSender() == owner());
        _mint(account, amount);
    }

    function burn(address account, uint amount) external {
        require(_msgSender() == owner());
        _burn(account, amount);
    }
}
