// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "permit2/src/interfaces/ISignatureTransfer.sol";

interface IAssetScooper {
    error AssetScooper__UnsuccessfulBalanceCall();
    error AssetScooper__InvalidAsset(address asset);
    error AssetScooper__InvalidTransferDetails(
        address assetScooper,
        uint256 userBal
    );
    error AssetScooper__InexactTransfer();

    event AssetSwapped(
        address indexed sender,
        address indexed asset,
        uint256 indexed amountOut
    );

    error AssetScooper__NotEnoughOutputAmount(uint256 amountOut);

    struct SwapParam {
        address asset;
        uint256 outputAmount;
    }

    function owner() external view returns (address);

    function version() external view returns (string memory);

    function sweepAsset(
        SwapParam memory param,
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        bytes memory sig
    ) external;
}
