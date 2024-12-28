// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockSwapRouter {
    function exactInputSingle(
        ISwapRouter.ExactInputSingleParams calldata params
    ) external returns (uint256 amountOut) {
        // First approve the router to spend input tokens
        IERC20(params.tokenIn).approve(address(this), params.amountIn);

        // Transfer input tokens from sender to router
        require(
            IERC20(params.tokenIn).transferFrom(
                msg.sender,
                address(this),
                params.amountIn
            ),
            "Transfer in failed"
        );

        // Mock output token transfer
        require(
            IERC20(params.tokenOut).transfer(
                params.recipient,
                params.amountOutMinimum
            ),
            "Transfer out failed"
        );

        return params.amountOutMinimum;
    }
}
