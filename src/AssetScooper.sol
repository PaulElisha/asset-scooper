// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "permit2/src/Permit2.sol";
import "./Interfaces/IAssetScooper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/interfaces/IWETH.sol";
import "@uniswap/v2-core/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/interfaces/IUniswapV2Pair.sol";

contract AssetScooper is
    IAssetScooper,
    Context,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    string private constant _version = "1.0.0";
    uint256 private constant STANDARD_DECIMAL = 18;
    address private _owner;

    IWETH private immutable weth;
    IUniswapV2Router02 private immutable uniswapRouter;
    IUniswapV2Factory private immutable uniswapFactory;
    Permit2 public immutable permit2;

    constructor(
        IWETH _weth,
        IUniswapV2Router02 _router,
        Permit2 _permit2,
        IUniswapV2Factory _uniswapFactory
    ) Ownable(_msgSender()) {
        weth = _weth;
        uniswapRouter = _router;
        uniswapFactory = _uniswapFactory;
        permit2 = _permit2;
        _owner = _msgSender();
    }

    function sweepAsset(
        IAssetScooper.SwapParam memory param,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes memory signature
    ) public whenNotPaused nonReentrant {
        if (
            param.assets.length != permit.permitted.length ||
            param.assets.length != param.minOutputAmounts.length ||
            param.minOutputAmounts.length <= 0
        ) {
            revert MismatchLength();
        }

        (
            ISignatureTransfer.SignatureTransferDetails[]
                memory transferDetails,
            uint256[] memory userBal
        ) = fillSignatureTransferArray(param, permit);

        preemptiveApproval(param, userBal);

        permit2.permitTransferFrom(
            permit,
            transferDetails,
            _msgSender(),
            signature
        );

        emit AssetTransferred(param, address(this), _msgSender());
        uint256 amountOut = swapTokens(param, userBal);
        emit AssetSwapped(_msgSender(), param, amountOut);
    }

    function swapTokens(
        IAssetScooper.SwapParam memory param,
        uint256[] memory amountIn
    ) internal returns (uint256 amountOut) {
        address tokenOut = param.tokenOut == address(0)
            ? address(weth)
            : param.tokenOut;

        bool[] memory liquidityExists = checkLiquidityPairs(
            param.assets,
            tokenOut
        );

        address[] memory path = new address[](2);
        path[1] = tokenOut;

        for (uint256 i = 0; i < param.assets.length; i++) {
            address tokenIn = param.assets[i];

            path[0] = tokenIn;

            if (!liquidityExists[i]) {
                emit InsufficientLiquidity(tokenIn, tokenOut);
                continue;
            }

            try
                uniswapRouter.swapExactTokensForTokens(
                    amountIn[i],
                    param.minOutputAmounts[i],
                    path,
                    _msgSender(),
                    param.deadline
                )
            returns (uint256[] memory amounts) {
                uint256 outputAmount = amounts[1];

                if (outputAmount < param.minOutputAmounts[i]) {
                    revert NotEnoughOutputAmount(outputAmount);
                }

                amountOut += outputAmount;
            } catch Error(string memory reason) {
                revert(string(abi.encodePacked("Swap failed: ", reason)));
            }
        }
        console.log("Sender balance", amountOut);
    }

    function fillSignatureTransferArray(
        IAssetScooper.SwapParam memory param,
        ISignatureTransfer.PermitBatchTransferFrom memory _permit
    )
        internal
        view
        returns (
            ISignatureTransfer.SignatureTransferDetails[]
                memory transferDetails,
            uint256[] memory userBalance
        )
    {
        uint256 length = param.assets.length;
        address[] memory assets = param.assets;

        transferDetails = new ISignatureTransfer.SignatureTransferDetails[](
            length
        );
        userBalance = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 balance = IERC20(assets[i]).balanceOf(_msgSender());

            uint8 decimals = IERC20Metadata(assets[i]).decimals();
            uint256 newBalance = normalizeTokenAmount(balance, decimals);

            if (assets[i] == _permit.permitted[i].token && balance > 0) {
                transferDetails[i] = ISignatureTransfer
                    .SignatureTransferDetails({
                        to: address(this),
                        requestedAmount: newBalance
                    });
            }
            userBalance[i] = balance;
        }
    }

    function checkLiquidityPairs(
        address[] memory assets,
        address tokenOut
    ) internal view returns (bool[] memory _hasLiquidity) {
        uint256 length = assets.length;
        _hasLiquidity = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            _hasLiquidity[i] = hasLiquidity(assets[i], tokenOut);
        }
    }

    function preemptiveApproval(
        IAssetScooper.SwapParam memory param,
        uint256[] memory userBal
    ) internal {
        for (uint256 i = 0; i < param.assets.length; i++) {
            if (userBal[i] > 0) {
                approveIfNeeded(param.assets[i], userBal[i]);
            }
        }
    }

    function approveIfNeeded(address asset, uint256 userBal) internal {
        uint256 currentAllowance = IERC20(asset).allowance(
            address(this),
            address(uniswapRouter)
        );

        if (currentAllowance < userBal) {
            IERC20(asset).safeIncreaseAllowance(
                address(uniswapRouter),
                userBal - currentAllowance
            );
        }
    }

    function hasLiquidity(
        address token0,
        address token1
    ) internal view returns (bool) {
        address pair = uniswapFactory.getPair(token0, token1);
        if (pair == address(0)) return false;

        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();
        return reserve0 > 0 && reserve1 > 0;
    }

    function normalizeTokenAmount(
        uint256 amount,
        uint8 decimal
    ) internal pure returns (uint256) {
        if (decimal > STANDARD_DECIMAL) {
            return amount / 10 ** (decimal - STANDARD_DECIMAL);
        }
        if (decimal < STANDARD_DECIMAL) {
            return amount * 10 ** STANDARD_DECIMAL - decimal;
        }
        return amount;
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
