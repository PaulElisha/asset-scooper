// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/interfaces/constants/Constants.sol";
import "../src/AssetScooper.sol";
import "permit2/src/Permit2.sol";

contract DeployAssetScooper is Script, Constants {
    AssetScooper assetScooper;
    Permit2 permit;

    function run() public returns (AssetScooper) {
        return deployAssetScooper();
    }

    function deployAssetScooper() public returns (AssetScooper) {
        vm.startBroadcast();
        assetScooper = new AssetScooper(
            ROUTER,
            V3_FACTORY,
            PERMIT2,
            PROTOCOL_FEE_RECIPIENT
        );
        vm.stopBroadcast();

        return (assetScooper);
    }
}
