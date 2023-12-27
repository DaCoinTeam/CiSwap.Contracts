// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "../interfaces/WETH10/IWETH10.sol";
import "../interfaces/IPoolDeployer.sol";
import "../interfaces/IFactory.sol";
import "../Pool.sol";
import "../interfaces/pool/IPool.sol";
import "./PeripheryImmutables.sol";
import "../interfaces/periphery/IPeripheryPayments.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract PeripheryPayment is
    IPeripheryPayments,
    PeripheryImmutables,
    Context
{
    using SafeERC20 for IERC20;

    receive() external payable {
        require(_msgSender() == WETH10);
    }

    function _pay(
        address token,
        address payer,
        address recipient,
        uint amountPay
    ) internal {
        if (token == WETH10 && address(this).balance >= amountPay) {
            IWETH10(WETH10).deposit{value: amountPay}();
            IWETH10(WETH10).transfer(recipient, amountPay);
        } else if (payer == address(this)) {
            IERC20(token).safeTransfer(recipient, amountPay);
        } else {
            IERC20(token).safeTransferFrom(payer, recipient, amountPay);
        }
    }

    function unwrapWETH10(
        uint amountMinimum,
        address recipient
    ) public payable override {
        uint balanceWETH10 = IWETH10(WETH10).balanceOf(address(this));
        require(balanceWETH10 >= amountMinimum, "Insufficient WETH10");

        if (balanceWETH10 > 0) {
            IWETH10(WETH10).withdraw(balanceWETH10);
            (bool success, ) = recipient.call{value: balanceWETH10}("");
            require(success);
        }
    }

    function refundETH() external payable override {
        uint balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = _msgSender().call{value: balance}("");
            require(success);
        }
    }
}
