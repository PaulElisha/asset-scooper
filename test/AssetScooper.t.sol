// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {AssetScooper} from "../src/AssetScooper.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// 0x9DE16c805A3227b9b92e39a446F9d56cf59fe640 BENTO
// 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb DAI
contract AssetScooperTest is Test {
    AssetScooper public assetScooper;
    IERC20 public dai;
    IERC20 public bento;

    function setUp() public {
        assetScooper = new AssetScooper();
        dai = IERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);
        bento = IERC20(0x9DE16c805A3227b9b92e39a446F9d56cf59fe640);
    }

    function testSweep() public {
        uint hundredDAI = 1 * 1e18;

        deal(address(dai), address(1), hundredDAI, true);
        deal(address(bento), address(1), hundredDAI, true);

        vm.startPrank(address(1));
        dai.approve(address(assetScooper), hundredDAI);
        bento.approve(address(assetScooper), hundredDAI);

        address[] memory tokens = new address[](2);
        tokens[0] = address(dai);
        tokens[1] = address(bento);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = 0;

        // assertEq(dai.balanceOf(address(1)), hundredDAI);
        assetScooper.sweepTokens(tokens, amounts);
    }
}
