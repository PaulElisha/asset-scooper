// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Constants.sol";
import "../src/AssetScooper.sol";
import "permit2/src/Permit2.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/interfaces/IWETH.sol";

contract DeployAssetScooper is Script, Constants {
    AssetScooper assetScooper;

    function run() public returns (AssetScooper, Permit2) {
        return deployAssetScooper();
    }

    function deployAssetScooper() public returns (AssetScooper, Permit2) {
        Permit2 permit = Permit2(permit2Address);

        vm.startBroadcast();
        assetScooper = new AssetScooper(
            IWETH(weth),
            IUniswapV2Router02(router),
            permit
        );
        vm.stopBroadcast();

        return (assetScooper, permit);
    }
}
