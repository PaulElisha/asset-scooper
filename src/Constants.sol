// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Constants {
    address public constant weth = 0x4200000000000000000000000000000000000006;
    address public constant router = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address public constant factory =
        0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address public constant permit2Address =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    address public constant AERO = 0x3C281A39944a2319aA653D81Cfd93Ca10983D234;
    address public constant WGC = 0xAfb89a09D82FBDE58f18Ac6437B3fC81724e4dF6;
    address public constant TOBY = 0xb8D98a102b0079B69FFbc760C8d857A31653e56e;
    address public constant BENTO = 0x9DE16c805A3227b9b92e39a446F9d56cf59fe640;
    address public constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // address public constant PRANK_USER =
    //     0xCafc0Cd0eC8DD6F69C68AdBDEc9F2B7EAFeE931f;

    string public constant fork_url =
        "https://base-mainnet.g.alchemy.com/v2/0yadBjzhtsJKAysNRGkKbCwD7qpmRknG";
}
