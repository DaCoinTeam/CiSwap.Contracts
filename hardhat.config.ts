import { HardhatUserConfig } from "hardhat/config"

import "@nomicfoundation/hardhat-toolbox"

import "hardhat-gas-reporter"
import "hardhat-contract-sizer"

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.23",
        settings: {
            optimizer: {
                enabled: true,
                runs: 500,
            },
        },
    },
    gasReporter: {
        currency: "ETH",
        enabled: true,
        gasPrice: 25,
    },
    // mocha: {
    //     parallel: true
    // }
}

export default config
