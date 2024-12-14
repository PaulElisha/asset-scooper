// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Constants.sol";
import "../src/AssetScooper.sol";
import "permit2/src/Permit2.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/interfaces/IWETH.sol";
import "@uniswap/v2-core/interfaces/IUniswapV2Factory.sol";

contract DeployAssetScooper is Script, Constants {
    AssetScooper assetScooper;
    Permit2 permit;

    function run() public returns (AssetScooper) {
        return deployAssetScooper();
    }

    function deployAssetScooper() public returns (AssetScooper) {
        vm.startBroadcast();
        assetScooper = new AssetScooper(weth, router, permit2Address, factory);
        vm.stopBroadcast();

        return (assetScooper);
    }
}
