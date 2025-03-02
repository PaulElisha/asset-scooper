// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Constants {
    address public constant ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address public constant PERMIT2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant V3_FACTORY =
        0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant PROTOCOL_FEE_RECIPIENT =
        0xaAB18af86BBc9e63C264e1EBC9277969228cA418;

    uint256 public constant STANDARD_DECIMAL = 18;
    uint256 public constant PROTOCOL_FEE_BPS = 10; // 0.1% fee (10 basis points)

    string public constant fork_url =
        "https://base-mainnet.g.alchemy.com/v2/0yadBjzhtsJKAysNRGkKbCwD7qpmRknG";
}
