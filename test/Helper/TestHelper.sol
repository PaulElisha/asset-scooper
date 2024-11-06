// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/Interfaces/IAssetScooper.sol";
import "../../src/AssetScooper.sol";
import "permit2/src/interfaces/ISignatureTransfer.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract TestHelper is EIP712 {
    constructor() EIP712("Permit2", "1") {}

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH =
        keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

    function createSwapParam(
        IERC20 asset
    ) public pure returns (IAssetScooper.SwapParam memory) {
        return
            IAssetScooper.SwapParam({asset: address(asset), outputAmount: 0});
    }

    function createSignatureTransferData(
        IERC20 asset,
        AssetScooper assetScooper,
        address user
    ) public view returns (IAssetScooper.Permit2TransferDetails memory) {
        uint256 bal = asset.balanceOf(user);

        ISignatureTransfer.TokenPermissions
            memory permittedTokens = ISignatureTransfer.TokenPermissions({
                token: address(asset),
                amount: bal
            });

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: permittedTokens,
                nonce: 0,
                deadline: block.timestamp + 1 days
            });

        // permit.permitted[0] = permittedTokens;

        ISignatureTransfer.SignatureTransferDetails
            memory transferDetail = ISignatureTransfer
                .SignatureTransferDetails({
                    to: address(assetScooper),
                    requestedAmount: bal
                });

        return
            IAssetScooper.Permit2TransferDetails({
                permit: permit,
                transferDetails: transferDetail
            });

        // ISignatureTransfer.SignatureTransferDetails[]
        //     memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](
        //         1
        //     );

        // transferDetails[0] = transferDetail;

        // AssetScooper.Permit2SignatureTransferData
        //     memory signatureTransferData = AssetScooper
        //         .Permit2SignatureTransferData({
        //             permit: permit,
        //             transferDetails: transferDetail
        //         });
    }

    function constructSig(
        ISignatureTransfer.PermitTransferFrom memory permit
    ) public view returns (bytes32 digest) {
        bytes32 mhash = hashPermit(permit);

        digest = _hashTypedDataV4(mhash);

        // console.log("Signer", ecrecover(digest, v, r, s));
        // assertEq(signer, ecrecover(digest, v, r, s));
        // console.log("Test Helper: Sig", sig);
    }

    function _hashTokenPermissions(
        ISignatureTransfer.TokenPermissions memory permitted
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permitted));
    }

    function hashPermit(
        ISignatureTransfer.PermitTransferFrom memory permit
    ) internal view returns (bytes32) {
        bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
        return
            keccak256(
                abi.encode(
                    _PERMIT_TRANSFER_FROM_TYPEHASH,
                    tokenPermissionsHash,
                    msg.sender,
                    permit.nonce,
                    permit.deadline
                )
            );
    }
}
