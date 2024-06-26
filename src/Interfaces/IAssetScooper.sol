// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IAssetScooper {
    event TokenSwapped(
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountIn,
        uint amountOut
    );

    function owner() external view returns (address);

    function version() external pure returns (string memory);

    function _getAmountIn(
        address token,
        uint256 tokenBalance
    ) external view returns (uint256 amountIn);

    function _getTokenBalance(
        address token,
        address _owner
    ) external view returns (uint256 tokenBalance);

    function sweepTokens(
        address[] calldata tokenAddress,
        uint256 minAmountOut
    ) external;

    function _swap(
        address pairAddress,
        uint256 minAmountOut
    ) external returns (uint256);
}
