// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Constants {
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant permit2Address =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant factory =
        0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    address public constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant AIXBT = 0x50dA645f148798F68EF2d7dB7C1CB22A6819bb2C;

    uint256 public constant STANDARD_DECIMAL = 18;

    // address public constant PRANK_USER =
    //     0xCafc0Cd0eC8DD6F69C68AdBDEc9F2B7EAFeE931f;

    string public constant fork_url =
        "https://base-mainnet.g.alchemy.com/v2/0yadBjzhtsJKAysNRGkKbCwD7qpmRknG";
}
