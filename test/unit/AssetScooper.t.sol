// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/Constants.sol";
import "../../src/AssetScooper.sol";
import "../../script/DeployAssetScooper.s.sol";
import "../../src/Interfaces/IAssetScooper.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../Helper/TestHelper.sol";

contract AssetScooperTest is Test, Constants {
    TestHelper testHelper;
    DeployAssetScooper deployAssetScooper;
    AssetScooper assetScooper;
    IAssetScooper.SwapParam swapParam;
    IAssetScooper.Permit2TransferDetails permit2TransferDetails;
    IERC20 aero;
    IERC20 wgc;

    address userA;
    address userB;

    uint256 privateKey;
    bytes32 digest;
    bytes sig;

    uint256 internal mainnetFork;

    function setUp() public {
        testHelper = new TestHelper();

        deployAssetScooper = new DeployAssetScooper();
        assetScooper = deployAssetScooper.run();

        privateKey = vm.envUint("PRIVATE_KEY");
        userA = vm.addr(privateKey);
        console2.log(userA);

        aero = IERC20(AERO);
        wgc = IERC20(WGC);

        mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);
    }

    function testOwner() public view {
        assertEq(assetScooper.owner(), msg.sender);
    }

    function testVersion() public view {
        assertEq(assetScooper.version(), "1.0.0");
    }

    function testSweepAsset() public {
        swapParam = testHelper.createSwapParam(aero);

        permit2TransferDetails = testHelper.createSignatureTransferData(
            aero,
            assetScooper,
            userA
        );

        digest = testHelper.constructSig(permit2TransferDetails.permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        sig = getSig(v, r, s);

        vm.startPrank(userA);

        assetScooper.sweepAsset(swapParam, permit2TransferDetails, sig);

        vm.stopPrank();
    }

    function getSig(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (bytes memory _sig) {
        _sig = bytes.concat(r, s, bytes1(v));
    }
}
