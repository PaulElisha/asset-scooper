// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../mocks/MockERC20.sol";
import "../../src/Constants.sol";
import "permit2/src/Permit2.sol";
import "../Helper/TestHelper.sol";
import "../mocks/MockSwapRouter.sol";
import "../../src/AssetScooper.sol";
import "../../script/DeployAssetScooper.s.sol";
import "../../src/Interfaces/IAssetScooper.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "permit2/src/interfaces/ISignatureTransfer.sol";

contract AssetScooperTest is Test, Constants, TestHelper {
    DeployAssetScooper deployAssetScooper;
    AssetScooper assetScooper;
    Permit2 permit2;
    IERC20 dai;
    IERC20 usdc;
    IERC20 aixbt;
    IERC20 weth;

    address userA;
    address userB;

    uint256 privateKey;
    bytes32 domain_separator;
    bytes signature;

    uint256 internal mainnetFork;

    function setUp() public {
        deployAssetScooper = new DeployAssetScooper();
        (assetScooper) = deployAssetScooper.run();

        permit2 = assetScooper.permit2();

        privateKey = vm.envUint("private_key");
        userA = vm.addr(privateKey);

        console2.log(userA);

        dai = IERC20(DAI);
        usdc = IERC20(USDC);
        weth = IERC20(WETH);
        aixbt = IERC20(AIXBT);

        mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);
    }

    function testOwner() public view {
        assertEq(assetScooper.owner(), msg.sender);
    }

    function testVersion() public view {
        assertEq(assetScooper.version(), "2.0.0");
    }

    function testSweepAssetWithSignature() public {
        address[] memory assets = new address[](1);
        uint256[] memory balances = new uint256[](1);
        uint256[] memory outputs = new uint256[](1);

        assets[0] = address(usdc);
        outputs[0] = 1e18;

        uint256 len = assets.length;

        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        // Get initial balances
        for (uint256 i; i < len; i++) {
            balances[i] = IERC20(assets[i]).balanceOf(userA);
            console.log("Balance Before Swap:", balances[i]);
            console.log(" Output Token Before Swap:", aixbt.balanceOf(userA));
        }

        vm.startPrank(userA);
        for (uint256 i; i < len; i++) {
            IERC20(assets[i]).approve(address(permit2), type(uint256).max);
        }
        vm.stopPrank();

        IAssetScooper.SwapParam memory swapParam = createSwapParam(
            assets,
            outputs,
            block.timestamp + 3600
        );

        ISignatureTransfer.TokenPermissions[]
            memory batchTokenPermissions = getBatchTokenPermissions(
                assets,
                balances
            );

        ISignatureTransfer.PermitBatchTransferFrom
            memory permit2_ = defaultERC20PermitBatchTransfer(
                batchTokenPermissions,
                nonce,
                block.timestamp + 3600
            );

        signature = getPermitTransferSignature(
            permit2_,
            privateKey,
            address(assetScooper),
            domain_separator
        );

        vm.startPrank(userA);
        assetScooper.sweepAsset(swapParam, permit2_, signature);
        vm.stopPrank();

        // Assert final balances
        for (uint256 i; i < len; i++) {
            console.log(
                "Balance After Swap:",
                IERC20(assets[i]).balanceOf(userA)
            );
            console.log(" Output Token After Swap:", aixbt.balanceOf(userA));
            assertEq(IERC20(assets[i]).balanceOf(userA), 0);
        }

        assertGt(aixbt.balanceOf(userA), 0);
        console.log("Output Token After Swap:", aixbt.balanceOf(userA));
    }

    function testInvalidSignature_SweepAsset() public {
        address[] memory assets = new address[](1);
        uint256[] memory balances = new uint256[](1);
        uint256[] memory outputs = new uint256[](1);

        assets[0] = address(aixbt);
        outputs[0] = 1e18;

        uint256 len = assets.length;

        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        // Get initial balances
        for (uint256 i; i < len; i++) {
            balances[i] = IERC20(assets[i]).balanceOf(userA);
            console.log("Balance Before Swap:", balances[i]);
        }

        vm.startPrank(userA);
        for (uint256 i; i < len; i++) {
            IERC20(assets[i]).approve(address(permit2), type(uint256).max);
        }
        vm.stopPrank();

        IAssetScooper.SwapParam memory swapParam = createSwapParam(
            assets,
            outputs,
            block.timestamp + 3600
        );

        ISignatureTransfer.TokenPermissions[]
            memory batchTokenPermissions = getBatchTokenPermissions(
                assets,
                balances
            );

        ISignatureTransfer.PermitBatchTransferFrom
            memory permit2_ = defaultERC20PermitBatchTransfer(
                batchTokenPermissions,
                nonce,
                block.timestamp + 3600
            );

        signature = getPermitTransferSignature(
            permit2_,
            privateKey,
            address(userA),
            domain_separator
        );

        vm.startPrank(userA);
        vm.expectRevert();
        assetScooper.sweepAsset(swapParam, permit2_, signature);
        vm.stopPrank();

        // Assert final balances
        for (uint256 i; i < len; i++) {
            assertLt(IERC20(assets[i]).balanceOf(userA), balances[i]);
        }

        console.log("Output Token:", usdc.balanceOf(userA));
        console.log("User output token balance:", usdc.balanceOf(userA));
    }
}
