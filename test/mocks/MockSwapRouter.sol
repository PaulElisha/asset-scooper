// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockSwapRouter {
    using SafeERC20 for IERC20;

    // Simulating Uniswap's exactInputSingle function
    function exactInputSingle(
        ISwapRouter.ExactInputSingleParams calldata params
    ) external returns (uint256 amountOut) {
        // Transfer input tokens from sender to router (this contract)
        IERC20(params.tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );

        // Simulate a simple swap outcome (for example, 1:1 for mock purposes)
        uint256 mockAmountOut = params.amountIn; // This is a mock, you could adjust based on a different logic

        // Ensure the amount out is at least the minimum amountOut
        require(
            mockAmountOut >= params.amountOutMinimum,
            "Amount out less than minimum"
        );

        // Transfer the output tokens to the recipient
        IERC20(params.tokenOut).safeTransfer(params.recipient, mockAmountOut);

        // Return the mocked amount out
        return mockAmountOut;
    }
}
