import { HardhatUserConfig } from "hardhat/config"

import "@nomicfoundation/hardhat-toolbox"

import "hardhat-gas-reporter"

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.23",
        settings: {
            optimizer: {
                enabled: true,
                runs: 2000,
            },
        },
    },
    // gasReporter: {
    //     currency: "ETH",
    //     enabled: true,
    //     gasPrice: 25,
    // },
    // mocha: {
    //     parallel: true
    // }
}

export default config
