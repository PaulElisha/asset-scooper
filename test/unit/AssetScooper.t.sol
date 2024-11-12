// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/Constants.sol";
import "../../src/AssetScooper.sol";
import "../../script/DeployAssetScooper.s.sol";
import "../../src/Interfaces/IAssetScooper.sol";
import "permit2/src/Permit2.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../Helper/TestHelper.sol";
import "permit2/src/interfaces/IPermit2.sol";
import "permit2/src/interfaces/ISignatureTransfer.sol";
import "../mocks/MockERC20.sol";

contract AssetScooperTest is Test, Constants, TestHelper {
    DeployAssetScooper deployAssetScooper;
    AssetScooper assetScooper;
    IAssetScooper.SwapParam swapParam;
    IERC20 aero;
    IERC20 wgc;
    MockERC20 mockERC20;
    Permit2 permit2;

    address userA;
    address userB;

    uint256 privateKey;
    bytes32 digest;
    bytes32 domain_separator;
    bytes sig;

    uint256 internal mainnetFork;

    function setUp() public {
        mockERC20 = new MockERC20();

        permit2 = new Permit2();
        assetScooper = new AssetScooper(
            IWETH(weth),
            IUniswapV2Router02(router),
            permit2
        );
        // deployAssetScooper = new DeployAssetScooper();
        // (assetScooper, _permit2) = deployAssetScooper.run();
        domain_separator = permit2.DOMAIN_SEPARATOR();

        privateKey = vm.envUint("private_key");
        userA = vm.addr(privateKey);

        // userA = makeAddr("userA");
        console2.log(userA);

        vm.startPrank(userA);

        mockERC20.mint(userA, 100 ether);

        uint256 balance = mockERC20.balanceOf(userA);
        assertEq(
            balance,
            100 ether,
            "User A should have 100 ether after minting"
        );

        vm.stopPrank();

        // aero = IERC20(AERO);
        // wgc = IERC20(WGC);

        // mainnetFork = vm.createFork(fork_url);
        // vm.selectFork(mainnetFork);
    }

    // function testMint() public {
    //     userA = makeAddr("userA");
    //     userB = makeAddr("userB");
    //     console2.log(userA);

    //     vm.startPrank(userA);

    //     mockERC20.mint(userA, 100 ether);

    //     uint256 balance = mockERC20.balanceOf(userA);
    //     assertEq(
    //         balance,
    //         100 ether,
    //         "User A should have 100 ether after minting"
    //     );

    //     vm.stopPrank();
    // }

    function testOwner() public view {
        assertEq(assetScooper.owner(), address(this));
    }

    function testVersion() public view {
        assertEq(assetScooper.version(), "1.0.0");
    }

    function testSweep() public {
        uint256 nonce = 0;
        swapParam = createSwapParam(mockERC20);

        // permit2TransferDetails = createSignatureTransferData(
        //     mockERC20,
        //     assetScooper,
        //     userA
        // );

        ISignatureTransfer.PermitTransferFrom
            memory permit2_ = defaultERC20PermitTransfer(
                address(mockERC20),
                nonce,
                mockERC20.balanceOf(userA)
            );

        // digest = constructSig(permit2TransferDetails.permit);

        ISignatureTransfer.SignatureTransferDetails
            memory transferDetails_ = getTransferDetails(
                address(assetScooper),
                mockERC20.balanceOf(userA)
            );

        sig = getPermitTransferSignature(
            permit2_,
            privateKey,
            domain_separator
        );

        vm.startPrank(userA);

        assetScooper.sweepAsset(swapParam, permit2_, transferDetails_, sig);

        vm.stopPrank();
    }
}
