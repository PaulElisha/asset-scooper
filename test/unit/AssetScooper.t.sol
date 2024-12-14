// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../mocks/MockERC20.sol";
import "../../src/Constants.sol";
import "permit2/src/Permit2.sol";
import "../Helper/TestHelper.sol";
import "../../src/AssetScooper.sol";
import "../../script/DeployAssetScooper.s.sol";
import "../../src/Interfaces/IAssetScooper.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "permit2/src/interfaces/ISignatureTransfer.sol";

contract AssetScooperTest is Test, Constants, TestHelper {
    DeployAssetScooper deployAssetScooper;
    AssetScooper assetScooper;
    Permit2 permit2;
    IERC20 aero;
    IERC20 wgc;
    IERC20 toby;
    IERC20 bento;
    IERC20 dai;

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

        privateKey = vm.envUint("PRIVATE_KEY");
        userA = vm.addr(privateKey);

        console2.log(userA);

        aero = IERC20(AERO);
        wgc = IERC20(WGC);
        toby = IERC20(TOBY);
        bento = IERC20(BENTO);
        dai = IERC20(DAI);

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
        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        uint256 aeroBalance = aero.balanceOf(userA);
        uint256 daiBalance = dai.balanceOf(userA);
        uint256 bentoBalance = bento.balanceOf(userA);
        uint256 tobyBalance = toby.balanceOf(userA);

        vm.startPrank(userA);
        aero.approve(address(permit2), aeroBalance);
        dai.approve(address(permit2), daiBalance);
        bento.approve(address(permit2), bentoBalance);
        toby.approve(address(permit2), tobyBalance);
        vm.stopPrank();

        address[] memory assets = new address[](4);
        address[] memory to = new address[](4);
        uint256[] memory outputs = new uint256[](4);
        uint256[] memory balances = new uint256[](4);

        assets[0] = address(aero);
        assets[1] = address(dai);
        assets[2] = address(bento);
        assets[3] = address(toby);

        to[0] = address(assetScooper);
        to[1] = address(assetScooper);
        to[2] = address(assetScooper);
        to[3] = address(assetScooper);

        outputs[0] = 0;
        outputs[1] = 0;
        outputs[2] = 0;
        outputs[3] = 0;

        balances[0] = aeroBalance;
        balances[1] = daiBalance;
        balances[2] = bentoBalance;
        balances[3] = tobyBalance;

        IAssetScooper.SwapParam memory swapParam = createSwapParam(
            assets,
            outputs,
            block.timestamp
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
                block.timestamp
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
    }

    function testInvalidSignature_SweepAsset() public {
        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        uint256 aeroBalance = aero.balanceOf(userA);
        uint256 daiBalance = dai.balanceOf(userA);
        uint256 bentoBalance = bento.balanceOf(userA);
        uint256 tobyBalance = toby.balanceOf(userA);

        vm.startPrank(userA);
        aero.approve(address(permit2), aeroBalance);
        dai.approve(address(permit2), daiBalance);
        bento.approve(address(permit2), bentoBalance);
        toby.approve(address(permit2), tobyBalance);
        vm.stopPrank();

        address[] memory assets = new address[](4);
        address[] memory to = new address[](4);
        uint256[] memory outputs = new uint256[](4);
        uint256[] memory balances = new uint256[](4);

        assets[0] = address(aero);
        assets[1] = address(dai);
        assets[2] = address(bento);
        assets[3] = address(toby);

        to[0] = address(assetScooper);
        to[1] = address(assetScooper);
        to[2] = address(assetScooper);
        to[3] = address(assetScooper);

        outputs[0] = 0;
        outputs[1] = 0;
        outputs[2] = 0;
        outputs[3] = 0;

        balances[0] = aeroBalance;
        balances[1] = daiBalance;
        balances[2] = bentoBalance;
        balances[3] = tobyBalance;

        IAssetScooper.SwapParam memory swapParam = createSwapParam(
            assets,
            outputs,
            block.timestamp
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
                block.timestamp
            );

        signature = getPermitTransferSignature(
            permit2_,
            privateKey,
            address(this),
            domain_separator
        );

        vm.startPrank(userA);
        vm.expectRevert();
        assetScooper.sweepAsset(swapParam, permit2_, signature);
        vm.stopPrank();
    }
}
