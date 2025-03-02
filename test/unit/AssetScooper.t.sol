// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../mocks/MockERC20.sol";
import "../../src/interfaces/constants/Constants.sol";
import "permit2/src/Permit2.sol";
import "../Helper/TestHelper.sol";
import "../mocks/MockSwapRouter.sol";
import "../../src/AssetScooper.sol";
import "../../script/DeployAssetScooper.s.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "permit2/src/interfaces/ISignatureTransfer.sol";

contract AssetScooperTest is Test, Constants, TestHelper {
    DeployAssetScooper deployAssetScooper;
    AssetScooper assetScooper;
    Permit2 permit2;
    IERC20 usdc;
    IERC20 aixbt;
    IERC20 brett;

    address public constant AIXBT = 0x4F9Fd6Be4a90f2620860d680c0d4d5Fb53d1A825;
    address public constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;

    address userA;

    uint256 privateKey;
    bytes32 domain_separator;
    bytes signature;

    uint256 internal mainnetFork;

    function setUp() public {
        assetScooper = new DeployAssetScooper().run();

        permit2 = assetScooper.permit2();

        privateKey = vm.envUint("private_key");
        userA = vm.addr(privateKey);

        usdc = IERC20(USDC);
        aixbt = IERC20(AIXBT);
        brett = IERC20(BRETT);

        mainnetFork = vm.createFork(fork_url);
        vm.selectFork(mainnetFork);
    }

    function testOwner() public view {
        assertEq(assetScooper.owner(), msg.sender);
    }

    function testVersion() public view {
        assertEq(assetScooper.version(), "2.0.0");
    }

    function testSweepAssetSingleWithSignature() public {
        address[] memory assets = new address[](1);
        uint256[] memory balances = new uint256[](1);
        uint256[] memory outputs = new uint256[](1);

        assets[0] = address(aixbt);
        outputs[0] = 0e18;

        uint256 len = assets.length;

        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        for (uint256 i; i < len; i++) {
            balances[i] = IERC20(assets[i]).balanceOf(userA);
            console.log("Token In Balance Before Swap:", balances[i]);
        }
        console.log("Token Out Before Swap:", usdc.balanceOf(userA));

        vm.startPrank(userA);
        for (uint256 i; i < len; i++) {
            IERC20(assets[i]).approve(address(permit2), type(uint256).max);
        }
        vm.stopPrank();

        IAssetScooper.SwapParam memory swapParam = createSwapParam(
            assets,
            outputs,
            block.timestamp + 100
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
                block.timestamp + 100
            );

        signature = getPermitTransferSignature(
            permit2_,
            privateKey,
            address(assetScooper),
            domain_separator
        );

        vm.startPrank(userA);
        assetScooper.sweepAsset(swapParam, permit2_, signature, userA);
        vm.stopPrank();

        for (uint256 i; i < len; i++) {
            console.log(
                "Token In Balance After Swap:",
                IERC20(assets[i]).balanceOf(userA)
            );
            assertEq(IERC20(assets[i]).balanceOf(userA), 0);
        }

        console.log(
            "Token Out Balance After swap:",
            IERC20(usdc).balanceOf(userA)
        );
        console.log(
            "Protocol Fee Recipient:",
            IERC20(usdc).balanceOf(PROTOCOL_FEE_RECIPIENT)
        );
        console.log(
            "Asset Scoooper Balance:",
            IERC20(swapParam.tokenOut).balanceOf(address(assetScooper))
        );
        assertGt(
            IERC20(usdc).balanceOf(userA),
            IERC20(assets[0]).balanceOf(userA)
        );
        assertEq(IERC20(usdc).balanceOf(address(assetScooper)), 0);
    }

    function testSweepAssetMultipleWithSignature() public {
        address[] memory assets = new address[](2);
        uint256[] memory balances = new uint256[](2);
        uint256[] memory outputs = new uint256[](2);

        assets[0] = address(aixbt);
        assets[1] = address(brett);
        outputs[0] = 0e18;
        outputs[1] = 0e18;

        uint256 len = assets.length;

        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        for (uint256 i; i < len; i++) {
            balances[i] = IERC20(assets[i]).balanceOf(userA);
            console.log("Token In Balance Before Swap:", balances[i]);
        }
        console.log("Token Out Before Swap:", usdc.balanceOf(userA));

        vm.startPrank(userA);
        for (uint256 i; i < len; i++) {
            IERC20(assets[i]).approve(address(permit2), type(uint256).max);
        }
        vm.stopPrank();

        IAssetScooper.SwapParam memory swapParam = createSwapParam(
            assets,
            outputs,
            block.timestamp + 100
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
                block.timestamp + 100
            );

        signature = getPermitTransferSignature(
            permit2_,
            privateKey,
            address(assetScooper),
            domain_separator
        );

        vm.startPrank(userA);
        assetScooper.sweepAsset(swapParam, permit2_, signature, userA);
        vm.stopPrank();

        for (uint256 i; i < len; i++) {
            console.log(
                "Token In Balance After Swap:",
                IERC20(assets[i]).balanceOf(userA)
            );
            assertEq(IERC20(assets[i]).balanceOf(userA), 0);
        }

        console.log(
            "Token Out Balance After swap:",
            IERC20(usdc).balanceOf(userA)
        );
        console.log(
            "Protocol Fee Recipient:",
            IERC20(usdc).balanceOf(PROTOCOL_FEE_RECIPIENT)
        );
        console.log(
            "Asset Scoooper Balance:",
            IERC20(swapParam.tokenOut).balanceOf(address(assetScooper))
        );

        console.log("Token Out Balance After swap:", usdc.balanceOf(userA));
        for (uint256 i; i < len; i++) {
            assertGt(
                IERC20(usdc).balanceOf(userA),
                IERC20(assets[i]).balanceOf(userA)
            );
        }
        assertEq(IERC20(usdc).balanceOf(address(assetScooper)), 0);
    }

    function testSweepAssetWithInvalidSignature() public {
        address[] memory assets = new address[](1);
        uint256[] memory balances = new uint256[](1);
        uint256[] memory outputs = new uint256[](1);

        assets[0] = address(aixbt);
        outputs[0] = 1e18;

        uint256 len = assets.length;

        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        for (uint256 i; i < len; i++) {
            balances[i] = IERC20(assets[i]).balanceOf(userA);
            console.log("Token In Balance Before Swap:", balances[i]);
        }
        console.log("Token Out Before Swap:", usdc.balanceOf(userA));

        vm.startPrank(userA);
        for (uint256 i; i < len; i++) {
            IERC20(assets[i]).approve(address(permit2), type(uint256).max);
        }
        vm.stopPrank();

        IAssetScooper.SwapParam memory swapParam = createSwapParam(
            assets,
            outputs,
            block.timestamp + 100
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
                block.timestamp + 100
            );

        signature = getPermitTransferSignature(
            permit2_,
            privateKey,
            address(userA),
            domain_separator
        );

        vm.expectRevert();
        vm.startPrank(userA);
        assetScooper.sweepAsset(swapParam, permit2_, signature, userA);
        vm.stopPrank();
    }

    function testSweepAssetWithInsufficientBalance() public {
        address[] memory assets = new address[](1);
        uint256[] memory balances = new uint256[](1);
        uint256[] memory outputs = new uint256[](1);

        assets[0] = address(aixbt);
        outputs[0] = 0e18;

        uint256 len = assets.length;

        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        console.log("Token In Balance Before Swap:", balances[0]);
        console.log("Token Out Before Swap:", usdc.balanceOf(userA));

        balances[0] = balances[0] + 1;

        vm.startPrank(userA);
        for (uint256 i; i < len; i++) {
            IERC20(assets[i]).approve(address(permit2), balances[0]);
        }
        vm.stopPrank();

        IAssetScooper.SwapParam memory swapParam = createSwapParam(
            assets,
            outputs,
            block.timestamp + 100
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
                block.timestamp + 100
            );

        signature = getPermitTransferSignature(
            permit2_,
            privateKey,
            address(assetScooper),
            domain_separator
        );

        vm.expectRevert();
        vm.startPrank(userA);
        assetScooper.sweepAsset(swapParam, permit2_, signature, userA);
        vm.stopPrank();
    }

    function testSweepAssetWithExpiredSignature() public {
        address[] memory assets = new address[](1);
        uint256[] memory balances = new uint256[](1);
        uint256[] memory outputs = new uint256[](1);

        assets[0] = address(aixbt);
        outputs[0] = 0e18;

        uint256 len = assets.length;

        uint256 nonce = 40;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        for (uint256 i; i < len; i++) {
            balances[i] = IERC20(assets[i]).balanceOf(userA);
            console.log("Token In Balance Before Swap:", balances[i]);
        }
        console.log("Token Out Before Swap:", usdc.balanceOf(userA));

        vm.startPrank(userA);
        for (uint256 i; i < len; i++) {
            IERC20(assets[i]).approve(address(permit2), type(uint256).max);
        }
        vm.stopPrank();

        uint256 futureDeadline = block.timestamp + 100;

        IAssetScooper.SwapParam memory swapParam = createSwapParam(
            assets,
            outputs,
            futureDeadline
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
                futureDeadline
            );

        signature = getPermitTransferSignature(
            permit2_,
            privateKey,
            address(assetScooper),
            domain_separator
        );

        console.log("Current Timestamp:", block.timestamp);
        console.log("Future Deadline:", futureDeadline);

        vm.warp(futureDeadline + 1);

        console.log("New Timestamp After Warp:", block.timestamp);

        vm.expectRevert();
        vm.startPrank(userA);
        assetScooper.sweepAsset(swapParam, permit2_, signature, userA);
        vm.stopPrank();
    }

    function testSweepAssetWithZeroAmount() public {
        address[] memory assets = new address[](1);
        uint256[] memory balances = new uint256[](1);
        uint256[] memory outputs = new uint256[](1);

        assets[0] = address(aixbt);
        outputs[0] = 0e18;

        uint256 len = assets.length;

        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        for (uint256 i; i < len; i++) {
            balances[i] = IERC20(assets[i]).balanceOf(userA);
            console.log("Token In Balance Before Swap:", balances[i]);
        }
        console.log("Token Out Before Swap:", usdc.balanceOf(userA));

        vm.startPrank(userA);
        for (uint256 i; i < len; i++) {
            IERC20(assets[i]).approve(address(permit2), 0);
        }
        vm.stopPrank();

        IAssetScooper.SwapParam memory swapParam = createSwapParam(
            assets,
            outputs,
            block.timestamp + 100
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
                block.timestamp + 100
            );

        signature = getPermitTransferSignature(
            permit2_,
            privateKey,
            address(assetScooper),
            domain_separator
        );

        vm.expectRevert();
        vm.startPrank(userA);
        assetScooper.sweepAsset(swapParam, permit2_, signature, userA);
        vm.stopPrank();
    }
}
