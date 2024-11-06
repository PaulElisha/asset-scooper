// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/IAssetScooper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "permit2/src/interfaces/IPermit2.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/interfaces/IWETH.sol";

contract AssetScooper is IAssetScooper, ReentrancyGuard {
    using SafeERC20 for IERC20;

    string private _version = "1.0.0";
    address private immutable _owner;

    IWETH private immutable weth;
    IUniswapV2Router02 private immutable uniswapRouter;
    IPermit2 private immutable signatureTransfer;

    constructor(
        IWETH _weth,
        IUniswapV2Router02 _router,
        IPermit2 _signatureTransfer
    ) {
        weth = _weth;
        uniswapRouter = _router;
        signatureTransfer = _signatureTransfer;
        _owner = msg.sender;
    }

    function sweepAsset(
        IAssetScooper.SwapParam memory param,
        Permit2TransferDetails memory permit2TransferDetails,
        bytes memory sig
    ) public {
        if (param.asset != permit2TransferDetails.permit.permitted.token) {
            revert AssetScooper__InvalidAsset(param.asset);
        }

        uint256 amountOut;
        IERC20 asset;

        asset = IERC20(param.asset);
        uint256 minAmountOut = param.outputAmount;
        uint256 tokenBalance = _getTokenBalance(address(asset), msg.sender);

        if (tokenBalance > 0) {
            if (
                permit2TransferDetails.transferDetails.to != address(this) ||
                permit2TransferDetails.transferDetails.requestedAmount !=
                tokenBalance ||
                permit2TransferDetails.permit.permitted.amount !=
                permit2TransferDetails.transferDetails.requestedAmount
            ) {
                revert AssetScooper__InvalidTransferDetails(
                    address(this),
                    tokenBalance
                );
            }
        }

        uint256 balanceBefore = _getTokenBalance(address(asset), address(this));

        signatureTransfer.permitTransferFrom(
            permit2TransferDetails.permit,
            permit2TransferDetails.transferDetails,
            msg.sender,
            sig
        );

        _revertIfAmountOutNotExactAmount(
            tokenBalance,
            balanceBefore,
            address(asset),
            address(this)
        );

        asset.approve(address(uniswapRouter), tokenBalance);

        address[] memory path = new address[](2);
        path[0] = address(asset);
        path[1] = address(weth);

        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            tokenBalance,
            minAmountOut,
            path,
            address(this),
            block.timestamp + 100 // Allowing a small time window for the swap to complete
        );

        amountOut += amounts[1];

        if (amountOut < minAmountOut) {
            revert AssetScooper__NotEnoughOutputAmount(amountOut);
        }

        emit AssetSwapped(msg.sender, address(asset), amountOut);
    }

    function _revertIfAmountOutNotExactAmount(
        uint256 expectedDiff,
        uint256 balanceBefore,
        address asset,
        address target
    ) private view {
        uint256 balanceAfter = _getTokenBalance(asset, target);
        if (balanceAfter - balanceBefore != expectedDiff) {
            revert AssetScooper__InexactTransfer();
        }
    }

    function _getTokenBalance(
        address token,
        address owner_
    ) private view returns (uint256 tokenBalance) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("balanceOf(address)", owner_)
        );
        if (!success || data.length <= 0) {
            revert AssetScooper__UnsuccessfulBalanceCall();
        }
        tokenBalance = abi.decode(data, (uint256));
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function version() public view returns (string memory) {
        return _version;
    }
}
