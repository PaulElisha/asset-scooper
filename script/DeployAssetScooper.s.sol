// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Constants.sol";
import "../src/AssetScooper.sol";
import "permit2/src/interfaces/IPermit2.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/interfaces/IWETH.sol";

contract DeployAssetScooper is Script, Constants {
    AssetScooper assetScooper;

    function run() public returns (AssetScooper) {
        return deployAssetScooper();
    }

    function deployAssetScooper() public returns (AssetScooper) {
        vm.startBroadcast();
        assetScooper = new AssetScooper(
            IWETH(weth),
            IUniswapV2Router02(router),
            IPermit2(permit2)
        );
        vm.stopBroadcast();

        return assetScooper;
    }
}
