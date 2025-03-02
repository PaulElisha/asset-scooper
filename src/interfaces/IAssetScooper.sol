// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "permit2/src/interfaces/ISignatureTransfer.sol";

interface IAssetScooper {
    error MismatchLength(uint256);
    error CannotApproveBalanceZeroOrLess();
    error PoolFeeNotFound(address tokenIn, address tokenOut);
    error ApprovalFailed(address);

    event AssetTransferred(
        SwapParam indexed param,
        address indexed receiver,
        address indexed sender
    );
    event SwapExecuted(address indexed sender, uint256 indexed amountOut);

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
        bytes memory signature,
        address to
    ) external;
}
