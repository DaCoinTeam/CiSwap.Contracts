// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract ExtendMulticall is Multicall {
    function multicall2(
        bytes[] calldata data
    ) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), data[i]);
        }
        return results;
    }
}
