// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/IAssetScooper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "permit2/src/Permit2.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/interfaces/IWETH.sol";
import "forge-std/console.sol";

contract AssetScooper is IAssetScooper, ReentrancyGuard {
    using SafeERC20 for IERC20;

    string private _version = "1.0.0";
    address private immutable _owner;

    IWETH private immutable weth;
    IUniswapV2Router02 private immutable uniswapRouter;
    Permit2 public immutable permit2;

    constructor(IWETH _weth, IUniswapV2Router02 _router, Permit2 _permit2) {
        weth = _weth;
        uniswapRouter = _router;
        permit2 = _permit2;
        _owner = msg.sender;
    }

    function sweepAsset(
        IAssetScooper.SwapParam memory param,
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        bytes memory sig
    ) public {
        if (param.asset != permit.permitted.token) {
            revert AssetScooper__InvalidAsset(param.asset);
        }

        // uint256 amountOut;
        // uint256 minAmountOut = param.outputAmount;
        uint256 tokenBalance = _getTokenBalance(param.asset, msg.sender);

        if (tokenBalance > 0) {
            if (
                transferDetails.to != address(this) ||
                transferDetails.requestedAmount != tokenBalance ||
                permit.permitted.amount != transferDetails.requestedAmount
            ) {
                revert AssetScooper__InvalidTransferDetails(
                    address(this),
                    tokenBalance
                );
            }
        }

        uint256 balanceBefore = _getTokenBalance(param.asset, address(this));
        console.log("Scooper Balance Before", balanceBefore);

        permit2.permitTransferFrom(permit, transferDetails, msg.sender, sig);

        _revertIfAmountOutNotExactAmount(
            tokenBalance,
            balanceBefore,
            param.asset,
            address(this)
        );

        uint256 balanceAfter = _getTokenBalance(param.asset, address(this));
        console.log("Scooper Balance After", balanceAfter);

        // asset.approve(address(uniswapRouter), tokenBalance);

        // address[] memory path = new address[](2);
        // path[0] = param.asset;
        // path[1] = address(weth);

        // uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
        //     tokenBalance,
        //     minAmountOut,
        //     path,
        //     address(this),
        //     block.timestamp + 100 // Allowing a small time window for the swap to complete
        // );

        // amountOut += amounts[1];

        // if (amountOut < minAmountOut) {
        //     revert AssetScooper__NotEnoughOutputAmount(amountOut);
        // }

        // emit AssetSwapped(msg.sender, address(asset), amountOut);
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
