// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Constants } from './Constants.sol';

library ChainConfig {

    error UnsupportedChainId(uint256 chainId);

    function getFeeByChainId(
        uint256 chainId
    ) internal pure returns (uint256) {
        if (chainId == Constants.SEPOLIA_CHAIN_ID) {
            return Constants.SEPOLIA_FEE;
        } else if (chainId == Constants.ETHEREUM_CHAIN_ID) {
            return Constants.ETHEREUM_FEE;
        } else if (chainId == Constants.AMOY_CHAIN_ID) {
            return Constants.AMOY_FEE;
        } else if (chainId == Constants.POLYGON_CHAIN_ID) {
            return Constants.POLYGON_FEE;
        } else {
            revert UnsupportedChainId(chainId);
        }
    }

}
