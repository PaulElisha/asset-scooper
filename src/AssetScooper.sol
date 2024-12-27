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
import "@uniswap/v3-periphery/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

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
    IUniswapV3Factory public immutable V3Factory;
    Permit2 public immutable permit2;

    string private constant _version = "2.0.0";
    uint256 private constant STANDARD_DECIMAL = 18;

    constructor(
        address _weth,
        address _router,
        address factory,
        address _permit2
    ) Ownable(_msgSender()) {
        weth = IWETH(_weth);
        swapRouter = ISwapRouter(_router);
        V3Factory = IUniswapV3Factory(factory);
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
    ) public whenNotPaused nonReentrant {
        uint256 len = param.assets.length;

        if (
            len != permit.permitted.length ||
            len != param.minOutputAmounts.length ||
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

        // ISwapRouter.ExactInputSingleParams[]
        //     memory swapParams = fillSwapParamArray(userBal, param, sender);

        preemptiveApproval(param, userBal);

        _permit2.permitTransferFrom(permit, transferDetails, sender, signature);

        emit AssetTransferred(param, sender, address(this));
        uint256 amountOut = swapTokens(param, userBal);
        emit AssetSwapped(sender, param, amountOut);
    }

    function swapTokens(
        IAssetScooper.SwapParam memory param,
        uint256[] memory amountIn
    ) private checkDeadline(param.deadline) returns (uint256 amountOut) {
        uint256 len = param.assets.length;

        // amountOut = swapRouter.exactInputSingle(params);

        for (uint256 i; i < len; i++) {
            address tokenIn = normalizeAddress(param.assets[i]);
            uint24 poolFee = getPoolFee(tokenIn, param.tokenOut);

            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: param.tokenOut,
                    fee: poolFee,
                    recipient: msg.sender,
                    deadline: block.timestamp,
                    amountIn: amountIn[i],
                    amountOutMinimum: param.minOutputAmounts[i],
                    sqrtPriceLimitX96: 0
                });

            try swapRouter.exactInputSingle(params) returns (uint256 amount) {
                if (amount < param.minOutputAmounts[i]) {
                    revert NotEnoughOutputAmount(amount);
                }

                amountOut += amount;
            } catch Error(string memory reason) {
                console.log("Swap failed for tokenIn:", params.tokenIn);
                revert(string(abi.encodePacked("Swap failed: ", reason)));
            }
        }
        console.log("Sender balance", amountOut);
    }

    function fillSwapParamArray(
        uint256[] memory amountIn,
        IAssetScooper.SwapParam memory param,
        address sender
    )
        private
        view
        returns (ISwapRouter.ExactInputSingleParams[] memory swapParams)
    {
        uint256 len = param.assets.length;
        swapParams = new ISwapRouter.ExactInputSingleParams[](len);

        require(param.tokenOut == address(weth) || param.tokenOut == USDC);

        for (uint256 i; i < len; i++) {
            address tokenIn = normalizeAddress(param.assets[i]);
            uint24 poolFee = getPoolFee(tokenIn, param.tokenOut);

            swapParams[i] = ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: param.tokenOut,
                fee: poolFee,
                recipient: sender,
                deadline: param.deadline,
                amountIn: amountIn[i],
                amountOutMinimum: param.minOutputAmounts[i],
                sqrtPriceLimitX96: 1
            });
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
            address asset = assets[i];
            uint8 decimals = IERC20Metadata(asset).decimals();
            uint256 balance = normalizeTokenAmount(
                IERC20(normalizeAddress(asset)).balanceOf(sender),
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
    ) private {
        uint256 len = param.assets.length;

        for (uint256 i; i < len; i++) {
            if (userBal[i] > 0) {
                approveIfNeeded(param.assets[i], userBal[i]);
            }
        }
    }

    function approveIfNeeded(address asset, uint256 userBal) private {
        // uint256 currentAllowance = IERC20(asset).allowance(
        //     address(this),
        //     address(swapRouter)
        // );

        IERC20(asset).approve(address(swapRouter), userBal);

        // if (currentAllowance < userBal) {
        //     uint256 approveAmount = userBal - currentAllowance;
        // }
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

    // function checkPool(
    //     address tokenIn,
    //     address tokenOut
    // ) private view returns (bool) {
    //     uint24[] memory feeTier = new uint24[](3);
    //     feeTier[0] = 500;
    //     feeTier[1] = 3000;
    //     feeTier[2] = 10000;

    //     uint256 len = feeTier.length;

    //     for (uint256 i; i < len; i++) {
    //         address pool = V3Factory.getPool(tokenIn, tokenOut, feeTier[i]);
    //         if (pool != address(0)) {

    //         }
    //     }
    // }

    function getPoolFee(
        address tokenIn,
        address tokenOut
    ) private view returns (uint24) {
        // uint24[3] memory feeTier;
        // feeTier[0] = 500;
        // feeTier[1] = 3000;
        // feeTier[2] = 10000;

        uint24[] memory feeTier = new uint24[](3);
        feeTier[0] = 500;
        feeTier[1] = 3000;
        feeTier[2] = 10000;

        uint256 len = feeTier.length;
        for (uint256 i; i < len; i++) {
            address pool = V3Factory.getPool(tokenIn, tokenOut, feeTier[i]);
            if (pool != address(0)) return feeTier[i];
        }

        revert("No valid pool");
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
