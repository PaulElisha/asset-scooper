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
    address public constant SWAP_ROUTER =
        0x2626664c2603336E57B271c5C0b26F421741e481;

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
        assertEq(assetScooper.version(), "2.0.0");
    }

    function testSweepAsset() public {
        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        // Mock the Uniswap Router
        MockSwapRouter mockRouter = new MockSwapRouter();
        vm.etch(SWAP_ROUTER, address(mockRouter).code);

        // Deal tokens to userA
        deal(address(aero), userA, 100e18);
        deal(address(dai), userA, 100e18);
        deal(address(bento), userA, 100e18);
        deal(address(toby), userA, 100e18);

        // Deal USDC to mock router and approve it
        deal(USDC, address(mockRouter), 1000e6);
        deal(USDC, SWAP_ROUTER, 1000e6);

        vm.startPrank(address(mockRouter));
        IERC20(USDC).approve(address(mockRouter), type(uint256).max);
        vm.stopPrank();

        // Get initial balances
        uint256 initialAeroBalance = aero.balanceOf(userA);
        uint256 initialDaiBalance = dai.balanceOf(userA);
        uint256 initialBentoBalance = bento.balanceOf(userA);
        uint256 initialTobyBalance = toby.balanceOf(userA);

        vm.startPrank(userA);
        aero.approve(address(permit2), type(uint256).max);
        dai.approve(address(permit2), type(uint256).max);
        bento.approve(address(permit2), type(uint256).max);
        toby.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        address[] memory assets = new address[](4);
        uint256[] memory outputs = new uint256[](4);
        uint256[] memory balances = new uint256[](4);

        assets[0] = address(aero);
        assets[1] = address(dai);
        assets[2] = address(bento);
        assets[3] = address(toby);

        balances[0] = initialAeroBalance;
        balances[1] = initialDaiBalance;
        balances[2] = initialBentoBalance;
        balances[3] = initialTobyBalance;

        // Set very small minimum outputs for USDC (6 decimals)
        outputs[0] = 1e4; // 0.01 USDC
        outputs[1] = 1e4;
        outputs[2] = 1e4;
        outputs[3] = 1e4;

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
        assertLt(aero.balanceOf(userA), initialAeroBalance);
        assertLt(dai.balanceOf(userA), initialDaiBalance);
        assertLt(bento.balanceOf(userA), initialBentoBalance);
        assertLt(toby.balanceOf(userA), initialTobyBalance);

        IERC20 outputToken = IERC20(USDC);
        assertGt(outputToken.balanceOf(userA), 0);
    }

    function testInvalidSignature_SweepAsset() public {
        uint256 nonce = 20;
        domain_separator = permit2.DOMAIN_SEPARATOR();

        // Mock the Uniswap Router
        MockSwapRouter mockRouter = new MockSwapRouter();
        vm.etch(SWAP_ROUTER, address(mockRouter).code);

        // Deal tokens to userA
        deal(address(aero), userA, 100e18);
        deal(address(dai), userA, 100e18);
        deal(address(bento), userA, 100e18);
        deal(address(toby), userA, 100e18);

        // Deal USDC to mock router and approve it
        deal(USDC, address(mockRouter), 1000e6);
        deal(USDC, SWAP_ROUTER, 1000e6);

        vm.startPrank(address(mockRouter));
        IERC20(USDC).approve(address(mockRouter), type(uint256).max);
        vm.stopPrank();

        // Get initial balances
        uint256 initialAeroBalance = aero.balanceOf(userA);
        uint256 initialDaiBalance = dai.balanceOf(userA);
        uint256 initialBentoBalance = bento.balanceOf(userA);
        uint256 initialTobyBalance = toby.balanceOf(userA);

        vm.startPrank(userA);
        aero.approve(address(permit2), type(uint256).max);
        dai.approve(address(permit2), type(uint256).max);
        bento.approve(address(permit2), type(uint256).max);
        toby.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        address[] memory assets = new address[](4);
        uint256[] memory outputs = new uint256[](4);
        uint256[] memory balances = new uint256[](4);

        assets[0] = address(aero);
        assets[1] = address(dai);
        assets[2] = address(bento);
        assets[3] = address(toby);

        balances[0] = initialAeroBalance;
        balances[1] = initialDaiBalance;
        balances[2] = initialBentoBalance;
        balances[3] = initialTobyBalance;

        // Set very small minimum outputs for USDC (6 decimals)
        outputs[0] = 1e4; // 0.01 USDC
        outputs[1] = 1e4;
        outputs[2] = 1e4;
        outputs[3] = 1e4;

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

        vm.expectRevert();
        vm.startPrank(userA);
        assetScooper.sweepAsset(swapParam, permit2_, signature);
        vm.stopPrank();
    }
}
