// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "permit2/src/Permit2.sol";
import "./Interfaces/IAssetScooper.sol";
import "./interfaces/IWETH.sol";
import "./Constants.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract AssetScooper is
    IAssetScooper,
    Constants,
    Context,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    address private immutable _owner;
    IWETH private immutable weth;
    ISwapRouter public immutable swapRouter;
    IUniswapV3Factory public immutable v3factory;
    Permit2 public immutable permit2;

    string private constant _version = "2.0.0";

    // bytes4 public constant SELECTOR = ; // bytes4(keccak256("multicall(bytes[])"));

    constructor(
        address _weth,
        address _router,
        address factory,
        address _permit2
    ) Ownable(_msgSender()) {
        weth = IWETH(_weth);
        swapRouter = ISwapRouter(_router);
        v3factory = IUniswapV3Factory(factory);
        permit2 = Permit2(_permit2);
        _owner = _msgSender();
    }

    modifier checkDeadline(uint256 deadline) {
        require(deadline >= block.timestamp, "Deadline Elapsed");
        _;
    }

    function sweepAsset(
        IAssetScooper.SwapParam memory param,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes memory signature
    ) public checkDeadline(param.deadline) whenNotPaused nonReentrant {
        uint256 len = param.assets.length;

        if (
            len != permit.permitted.length &&
            len != param.minOutputAmounts.length &&
            len <= 0
        ) {
            revert MismatchLength(len);
        }

        address sender = _msgSender();
        Permit2 _permit2 = permit2;

        (
            ISignatureTransfer.SignatureTransferDetails[]
                memory transferDetails,
            uint256[] memory userBal
        ) = fillSignatureTransferDetailsArray(param, permit, sender);

        bytes[] memory callData = fillSwapCallData(userBal, param, sender);

        if (!preemptiveApproval(param, userBal))
            revert CannotApproveBalanceZeroOrLess();

        _permit2.permitTransferFrom(permit, transferDetails, sender, signature);

        emit AssetTransferred(param, sender, address(this));
        uint256 amountOut = batchSwap(callData);
        emit SwapExecuted(sender, param, amountOut);
    }

    function batchSwap(
        bytes[] memory calls
    ) private returns (uint256 amountOut) {
        require(calls.length > 0, "No valid swaps to execute");

        bytes memory multicallData = abi.encodeWithSelector(0xac9650d8, calls);

        (bool success, bytes memory result) = router.call(multicallData);
        require(success, "Swap failed");

        if (result.length > 0) {
            amountOut = abi.decode(result, (uint256));
        }
    }

    function fillSwapCallData(
        uint256[] memory amountIn,
        IAssetScooper.SwapParam memory param,
        address sender
    ) private view returns (bytes[] memory calls) {
        uint256 len = param.assets.length;
        address[] memory assets = param.assets;
        calls = new bytes[](len);
        address tokenOut = param.tokenOut == address(weth)
            ? address(weth)
            : USDC;

        for (uint256 i; i < len; i++) {
            address tokenIn = normalizeAddress(assets[i]);
            uint24 poolFee = getPoolFee(tokenIn, tokenOut);
            bool poolExists = poolExistsWithLiquidity(
                tokenIn,
                tokenOut,
                poolFee
            );

            if (poolExists) {
                bytes memory encData = abi.encodeWithSelector(
                    ISwapRouter.exactInputSingle.selector,
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        fee: poolFee,
                        recipient: sender,
                        deadline: param.deadline,
                        amountIn: amountIn[i],
                        amountOutMinimum: param.minOutputAmounts[i],
                        sqrtPriceLimitX96: 0
                    })
                );

                calls[i] = encData;
            }
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
            ISignatureTransfer.SignatureTransferDetails[]
                memory transferDetails,
            uint256[] memory userBalance
        )
    {
        uint256 len = param.assets.length;
        address[] memory assets = param.assets;

        transferDetails = new ISignatureTransfer.SignatureTransferDetails[](
            len
        );
        userBalance = new uint256[](len);

        for (uint256 i; i < len; i++) {
            address asset = normalizeAddress(assets[i]);
            uint8 decimals = IERC20Metadata(asset).decimals();
            uint256 balance = normalizeTokenAmount(
                IERC20(asset).balanceOf(sender),
                decimals
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
            uint256 approveAmount = userBal - currentAllowance;

            IERC20(asset).safeIncreaseAllowance(
                address(swapRouter),
                approveAmount
            );

            return true;
        }

        return false;
    }

    function normalizeAddress(address addr) private pure returns (address) {
        return address(uint160(addr));
    }

    function normalizeTokenAmount(
        uint256 amount,
        uint8 decimal
    ) private pure returns (uint256) {
        if (decimal > STANDARD_DECIMAL) {
            return amount / 10 ** (decimal - STANDARD_DECIMAL);
        } else if (decimal < STANDARD_DECIMAL) {
            return amount * 10 ** (STANDARD_DECIMAL - decimal);
        }
        return amount;
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

            if (pool != address(0)) {
                return feeTier[index];
            }

            index++;
        }
        revert PoolFeeNotFound(tokenIn, tokenOut);
    }

    function poolExistsWithLiquidity(
        address tokenIn,
        address tokenOut,
        uint24 fee
    ) private view returns (bool) {
        address _pool = v3factory.getPool(tokenIn, tokenOut, fee);
        (bool success, bytes memory data) = _pool.staticcall(
            abi.encodeWithSignature("liquidity()")
        );
        if (!success) {
            return false;
        }

        uint128 liquidity = abi.decode(data, (uint128));
        if (!(liquidity > 0))
            revert PoolHasNoLiquidity(_pool, tokenIn, tokenOut);
        else return true;
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
