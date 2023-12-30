// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "./interfaces/IFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPoolDeployer.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./base/PoolDeployer.sol";
import "./interfaces/pool/IPool.sol";
import "./libraries/TokenLib.sol";
import "./libraries/SafeTransfer.sol";

contract Factory is IFactory, Ownable, PoolDeployer {
    using SafeCast for *;

    address public override feeTo;

    mapping(uint24 => bool) public override getFeeAmountEnabled;
    mapping(address => mapping(address => address[])) public override getPool;
    address[] public override pools;

    function allPools() external view returns (address[] memory) {
        return pools;
    }

    constructor() Ownable(_msgSender()) {
        getFeeAmountEnabled[250] = true;
        emit FeeAmountEnabled(250);
        getFeeAmountEnabled[500] = true;
        emit FeeAmountEnabled(500);
        getFeeAmountEnabled[1000] = true;
        emit FeeAmountEnabled(1000);
        getFeeAmountEnabled[2500] = true;
        emit FeeAmountEnabled(2500);

        feeTo = _msgSender();
    }

    function createPool(
        CreatePoolParams calldata params
    ) external override returns (address pool) {
        require(params.config.tokenA != params.config.tokenB, "Same tokens");

        require(
            params.config.basePriceAX96 < params.config.maxPriceAX96,
            "Max less base"
        );

        require(getFeeAmountEnabled[params.fee], "Fee not enabled");

        pool = deploy(
            DeployParams({
                factory: address(this),
                fee: params.fee,
                config: params.config
            })
        );

        pools.push(pool);

        (address token0, address token1, bool order) = TokenLib.sortTokens(
            params.config.tokenA,
            params.config.tokenB
        );

        (uint amount0, uint amount1) = order
            ? (params.config.amountA, params.config.amountB)
            : (params.config.amountB, params.config.amountA);

        SafeTransfer.transferFrom(token0, _msgSender(), pool, amount0);
        SafeTransfer.transferFrom(token1, _msgSender(), pool, amount1);
        Ownable(pool).transferOwnership(_msgSender());

        getPool[token0][token1].push(pool);
        getPool[token1][token0].push(pool);

        uint32 indexPool = getPool[token0][token1].length.toUint32() - 1;

        IPool(pool).initialize(indexPool);

        emit PoolCreated(_msgSender(), params.config, pool);
    }

    function setFeeTo(address account) external override {
        feeTo = account;
    }
}
