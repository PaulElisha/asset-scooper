// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "permit2/src/interfaces/ISignatureTransfer.sol";

interface IAssetScooper {
    error UnsuccessfulBalanceCall();
    error InexactTransfer();
    error NotEnoughOutputAmount(uint256 amountOut);
    error MismatchLength(uint256);
    error NoLiquidity(address token0, address token1);

    event AssetTransferred(SwapParam indexed param, address indexed receiver, address indexed sender);
    event AssetSwapped(address indexed sender, SwapParam indexed param, uint256 indexed amountOut);
    event InsufficientLiquidity(address indexed token0, address indexed token1);

    struct SwapParam {
        address[] assets;
        uint256[] minOutputAmounts;
        address tokenOut;
        uint256 deadline;
    }

    function owner() external view returns (address);

    function version() external view returns (string memory);

    function sweepAsset(
        SwapParam memory param,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes memory signature
    ) external;
}
