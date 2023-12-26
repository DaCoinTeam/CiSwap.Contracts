// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library SafeTransfer {
    using SafeERC20 for IERC20;

    function transfer(address token, address to, uint256 amount) internal {
        IERC20(token).safeTransfer(to, amount);
    }

    function transferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        return IERC20(token).safeTransferFrom(from, to, amount);
    }
}
