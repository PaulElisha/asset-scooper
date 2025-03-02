// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "permit2/src/Permit2.sol";
import "./interfaces/IAssetScooper.sol";
import "./interfaces/constants/Constants.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@swap-router/contracts/interfaces/ISwapRouter02.sol";
import "@swap-router/contracts/interfaces/IV3SwapRouter.sol";
import "@uniswap/v3-core/contracts/libraries/TransferHelper.sol";

contract AssetScooper is
    IAssetScooper,
    Constants,
    Context,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    address public immutable _owner;
    address public immutable protocolFeeRecipient;
    ISwapRouter02 public swapRouter;
    IUniswapV3Factory public immutable v3factory;
    Permit2 public immutable permit2;

    string public constant _version = "2.0.0";

    constructor(
        address _router,
        address factory,
        address _permit2,
        address _protocolFeeRecipient
    ) Ownable(_msgSender()) {
        swapRouter = ISwapRouter02(_router);
        v3factory = IUniswapV3Factory(factory);
        permit2 = Permit2(_permit2);
        _owner = _msgSender();
        protocolFeeRecipient = _protocolFeeRecipient;
    }

    modifier checkDeadline(uint256 deadline) {
        require(deadline >= block.timestamp, "Deadline Elapsed");
        _;
    }

    function sweepAsset(
        IAssetScooper.SwapParam memory param,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes memory signature,
        address to
    ) external checkDeadline(param.deadline) whenNotPaused nonReentrant {
        uint256 len = param.assets.length;

        if (
            len != permit.permitted.length ||
            len != param.minOutputAmounts.length ||
            len <= 0
        ) revert MismatchLength(len);

        (
            uint256[] memory userBal,
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails
        ) = fillSignatureTransferDetailsArray(param, permit, _msgSender());

        bytes[] memory callData = fillSwapCallData(userBal, param);

        if (!preemptiveApproval(param, userBal))
            revert CannotApproveBalanceZeroOrLess();

        permit2.permitTransferFrom(
            permit,
            transferDetails,
            _msgSender(),
            signature
        );

        emit AssetTransferred(param, _msgSender(), address(this));
        batchSwap(param.deadline, callData);

        uint256 outputTokenBalance = IERC20(param.tokenOut).balanceOf(
            address(this)
        );

        (uint256 protocolFee, uint256 amountOutMinusFee) = calculateProtocolFee(
            outputTokenBalance
        );

        if (protocolFee > 0) {
            IERC20(param.tokenOut).safeTransfer(
                protocolFeeRecipient,
                protocolFee
            );
        } else {
            revert("Insufficient Output token");
        }

        IERC20(param.tokenOut).safeTransfer(to, amountOutMinusFee);

        emit SwapExecuted(_msgSender(), amountOutMinusFee);
    }

    function batchSwap(uint256 deadline, bytes[] memory calls) private {
        require(calls.length > 0, "No valid swaps to execute");

        (bool success, ) = address(swapRouter).call(
            abi.encodeWithSelector(0x5ae401dc, deadline, calls)
        );
        require(success, "Swap failed");
    }

    function fillSwapCallData(
        uint256[] memory amountIn,
        IAssetScooper.SwapParam memory param
    ) private view returns (bytes[] memory calls) {
        address[] memory assets = param.assets;
        calls = new bytes[](assets.length);
        require(param.tokenOut == USDC);

        for (uint256 i; i < assets.length; i++) {
            address tokenIn = assets[i];
            uint24 poolFee = getPoolFee(tokenIn, param.tokenOut);

            calls[i] = abi.encodeWithSelector(
                swapRouter.exactInputSingle.selector,
                IV3SwapRouter.ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: param.tokenOut,
                    fee: poolFee,
                    recipient: address(this),
                    amountIn: amountIn[i],
                    amountOutMinimum: param.minOutputAmounts[i],
                    sqrtPriceLimitX96: 0
                })
            );
        }
    }

    function fillSignatureTransferDetailsArray(
        IAssetScooper.SwapParam memory param,
        ISignatureTransfer.PermitBatchTransferFrom memory _permit,
        address sender
    )
        private
        view
        returns (
            uint256[] memory userBalance,
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails
        )
    {
        address[] memory assets = param.assets;

        transferDetails = new ISignatureTransfer.SignatureTransferDetails[](
            assets.length
        );
        userBalance = new uint256[](assets.length);

        for (uint256 i; i < assets.length; i++) {
            address asset = assets[i];
            uint256 balance = normalizeTokenAmount(
                IERC20(asset).balanceOf(sender),
                IERC20Metadata(asset).decimals()
            );
            if (balance > 0 && asset == _permit.permitted[i].token) {
                transferDetails[i] = ISignatureTransfer
                    .SignatureTransferDetails({
                        to: address(this),
                        requestedAmount: balance
                    });
            }
            userBalance[i] = balance;
        }
    }

    function preemptiveApproval(
        IAssetScooper.SwapParam memory param,
        uint256[] memory userBal
    ) private returns (bool success) {
        uint256 len = param.assets.length;

        for (uint256 i; i < len; i++) {
            success = approveIfNeeded(param.assets[i], userBal[i]);
            if (!success) return false;
        }
        console.log("Approved SwapRouter Successfully!");
        return true;
    }

    function approveIfNeeded(
        address asset,
        uint256 userBal
    ) private returns (bool success) {
        uint256 currentAllowance = IERC20(asset).allowance(
            address(this),
            address(swapRouter)
        );

        if (currentAllowance < userBal) {
            IERC20(asset).safeIncreaseAllowance(
                address(swapRouter),
                userBal - currentAllowance
            );
            success = true;
        }
    }

    function normalizeTokenAmount(
        uint256 amount,
        uint8 decimal
    ) private pure returns (uint256) {
        return
            decimal < STANDARD_DECIMAL
                ? amount * (10 ** (STANDARD_DECIMAL - decimal))
                : amount;
    }

    function getPoolFee(
        address tokenIn,
        address tokenOut
    ) private view returns (uint24) {
        uint24[] memory feeTier = new uint24[](4);
        feeTier[0] = 100;
        feeTier[1] = 500;
        feeTier[2] = 3000;
        feeTier[3] = 10000;

        uint256 index = 0;
        uint256 len = feeTier.length;
        while (index < len) {
            address pool = v3factory.getPool(tokenIn, tokenOut, feeTier[index]);

            if (pool != address(0) && hasliquidity(pool)) {
                console.log("Found pool for:", tokenIn, tokenOut, pool);
                console.log("Found fee for", tokenIn, tokenOut, feeTier[index]);
                return feeTier[index];
            }

            index++;
        }
        revert PoolFeeNotFound(tokenIn, tokenOut);
    }

    function hasliquidity(address _pool) private view returns (bool success) {
        IUniswapV3Pool pool = IUniswapV3Pool(_pool);
        uint128 liquidity = pool.liquidity();
        console.log("Liquidity:", liquidity);

        if (liquidity > 0) {
            return true;
        }
        console.log("Pool has no liquidity");
        return false;
    }

    function calculateProtocolFee(
        uint256 outputTokenBalance
    ) private pure returns (uint256, uint256) {
        uint256 protocolFee = Math.mulDiv(
            outputTokenBalance,
            PROTOCOL_FEE_BPS,
            10_000
        );

        uint256 amountOutMinusFee = outputTokenBalance - protocolFee;

        return (protocolFee, amountOutMinusFee);
    }

    function calculateAmountOutMinusFee(
        uint256 totalOutput,
        uint256 protocolFee
    ) private pure returns (uint256) {
        return totalOutput - protocolFee;
    }

    function owner()
        public
        view
        override(Ownable, IAssetScooper)
        returns (address)
    {
        return _owner;
    }

    function version() public pure returns (string memory) {
        return _version;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
