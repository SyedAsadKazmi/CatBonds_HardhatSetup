// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library NetworkConfig {
    error NetworkConfig__NetworkNotSupported();

    function getRouterAddressForCCIP(uint256 chainId)
        internal
        pure
        returns (address router)
    {
        if (chainId == 43113) {
            router = 0xF694E193200268f9a4868e4Aa017A0118C9a8177;
        } else if (chainId == 80002) {
            router = 0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2;
        } else {
            revert NetworkConfig__NetworkNotSupported();
        }
    }

    function getChainSelector(uint256 chainId)
        internal
        pure
        returns (uint64 chainSelector)
    {
        if (chainId == 43113) {
            chainSelector = 14767482510784806043;
        } else if (chainId == 80002) {
            chainSelector = 16281711391670634445;
        } else {
            revert NetworkConfig__NetworkNotSupported();
        }
    }

    function getLinkTokenAddress(uint256 chainId)
        internal
        pure
        returns (address link)
    {
        if (chainId == 43113) {
            link = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
        } else if (chainId == 80002) {
            link = 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904;
        } else {
            revert NetworkConfig__NetworkNotSupported();
        }
    }

    function getUsdcTokenAddress(uint256 chainId)
        internal
        pure
        returns (address usdc)
    {
        if (chainId == 43113) {
            usdc = 0x5425890298aed601595a70AB815c96711a31Bc65;
        } else if (chainId == 80002) {
            usdc = 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582;
        } else {
            revert NetworkConfig__NetworkNotSupported();
        }
    }

    function getRouterAddressForChainlinkFunctions(uint256 chainId)
        internal
        pure
        returns (address router)
    {
        if (chainId == 43113) {
            router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
        } else if (chainId == 80002) {
            router = 0xC22a79eBA640940ABB6dF0f7982cc119578E11De;
        } else {
            revert NetworkConfig__NetworkNotSupported();
        }
    }

    function getDONIdForChainlinkFunctions(uint256 chainId)
        internal
        pure
        returns (bytes32 donId)
    {
        if (chainId == 43113) {
            donId = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;
        } else if (chainId == 80002) {
            donId = 0x66756e2d706f6c79676f6e2d616d6f792d310000000000000000000000000000;
        } else {
            revert NetworkConfig__NetworkNotSupported();
        }
    }

    function getEncryptedSecretsUrlForChainlinkFunctions(uint256 chainId)
        internal
        pure
        returns (bytes memory encryptedSecretsUrl)
    {
        if (chainId == 43113) {
            encryptedSecretsUrl = hex"9b52286ab0b5e923735c965e8bac2d11026e2bfaa7a313b1b009adacab005cc0953fddd57ca08765f5d45191ff8e5f9b4f63bee0dff2c4e28e737bc9191864a39461a5b396751f8fd0f65d47c9e50a54ce0f9cdab7eda2f40bb2c3947ec35622332e62cc4f6ddd9c6d1416710e1c1e1bab2895d491df65f174d13dd300af2f9d983c8eadc062db369f50d7a8bb5e649d84dbf1be9e318bdccc680daa3a398e601e";
        } else if (chainId == 80002) {
            encryptedSecretsUrl = hex"5e1da7cb5a70d02a362dabf38478a41302d1941d9466e46cd6f56a173fbf30eff49ea916a4dbbc107b42e4dfd170f3c69b8a327992cd28fe9f4106c5bf8b694506d836b93b8985cad182e1f4e5aeaec2a1539d0e509ad78d0f260b4ffcbfbc0e42adab717596b04dc430c62514cf6585b7a90237231fda13dc94c4547a6a515add18b1aa8e60986df979e720c3dc4df66340755ec31f639dd82325f111c7dabe66";
        } else {
            revert NetworkConfig__NetworkNotSupported();
        }
    }

    function getSubscriptionIdForChainlinkFunctions(uint256 chainId)
        internal
        pure
        returns (uint64 subscriptionId)
    {
        if (chainId == 43113) {
            subscriptionId = 8633;
        } else if (chainId == 80002) {
            subscriptionId = 237;
        } else {
            revert NetworkConfig__NetworkNotSupported();
        }
    }
}
