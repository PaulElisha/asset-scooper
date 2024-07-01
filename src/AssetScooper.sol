// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// Import necessary contracts from Uniswap
import "./Interfaces/IUniswapV2Pair.sol";
import "./Lib/UniswapV2Library.sol";
import "./Lib/TransferHelper.sol";
import "solady/ReentrancyGuard.sol";

contract AssetScooper is ReentrancyGuard {
    address private immutable i_owner;

    string private constant i_version = "1.0.0";

    address private constant weth = 0x4200000000000000000000000000000000000006;

    address private constant factory =
        0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;

    event TokenSwapped(
        address indexed user,
        address indexed tokenA,
        uint256 amountIn,
        uint256 indexed amountOut
    );

    error AssetScooper__ZeroLengthArray();
    error AssetScooper__InsufficientOutputAmount();
    error AssetScooper__UnsuccessfulBalanceCall();
    error AssetScooper__UnsuccessfulDecimalCall();
    error AssetScooper__InsufficientBalance();
    error AssetScooper__MisMatchLength();

    constructor() {
        i_owner = msg.sender;
    }

    function owner() public view returns (address) {
        return i_owner;
    }

    function version() public pure returns (string memory) {
        return i_version;
    }

    function _getAmountIn(
        address token,
        uint256 tokenBalance
    ) internal view returns (uint256 amountIn) {
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x313ce56700000000000000000000000000000000000000000000000000000000
            ) // decimals() signature
            if iszero(staticcall(gas(), token, ptr, 0x04, ptr, 0x20)) {
                revert(0, 0)
            }
            let tokenDecimals := mload(ptr)
            amountIn := mul(tokenBalance, exp(10, sub(18, tokenDecimals)))
        }
    }

    function _getTokenBalance(
        address token,
        address _owner
    ) internal view returns (uint256 tokenBalance) {
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x70a0823100000000000000000000000000000000000000000000000000000000
            ) // balanceOf(address) signature
            mstore(add(ptr, 0x04), _owner)
            if iszero(staticcall(gas(), token, ptr, 0x24, ptr, 0x20)) {
                revert(0, 0)
            }
            tokenBalance := mload(ptr)
        }
    }

    function sweepTokens(
        address[] calldata tokenAddress,
        uint256[] calldata minAmountOut
    ) public nonReentrant {
        if (tokenAddress.length == 0) revert AssetScooper__ZeroLengthArray();
        if (tokenAddress.length != minAmountOut.length)
            revert AssetScooper__MisMatchLength();

        uint256 totalEth;

        for (uint256 i = 0; i < tokenAddress.length; i++) {
            address pairAddress = UniswapV2Library.pairFor(
                factory,
                tokenAddress[i],
                weth
            );
            totalEth += _swap(pairAddress, minAmountOut[i], address(this));
        }
        TransferHelper.safeTransfer(weth, msg.sender, totalEth);
    }

    function _swap(
        address pairAddress,
        uint256 minimumOutputAmount,
        address _to
    ) private returns (uint256 amountOut) {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        address tokenA = pair.token0();
        address tokenB = pair.token1();
        address tokenIn = tokenA == weth ? tokenB : tokenA;
        address tokenOut = tokenA == weth ? tokenA : tokenB;

        uint256 tokenBalance = _getTokenBalance(tokenIn, msg.sender);
        if (tokenBalance == 0) revert AssetScooper__InsufficientBalance();

        uint256 amountIn = _getAmountIn(tokenIn, tokenBalance);
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(
            factory,
            tokenA,
            tokenB
        );

        amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            tokenIn == tokenA ? reserveA : reserveB,
            tokenIn == tokenA ? reserveB : reserveA
        );

        if (amountOut < minimumOutputAmount)
            revert AssetScooper__InsufficientOutputAmount();

        TransferHelper.safeTransferFrom(
            tokenIn,
            msg.sender,
            pairAddress,
            amountIn
        );

        (address token0, ) = UniswapV2Library.sortTokens(tokenIn, tokenOut);
        (uint amount0Out, uint amount1Out) = tokenIn == token0
            ? (uint(0), amountOut)
            : (amountOut, uint(0));

        address to = tokenA == address(0) && tokenB == address(0)
            ? UniswapV2Library.pairFor(
                factory,
                weth,
                tokenIn == weth ? tokenOut : tokenA
            )
            : _to;

        pair.swap(amount0Out, amount1Out, to, new bytes(0));

        emit TokenSwapped(msg.sender, tokenIn, amountIn, amountOut);
    }
}
