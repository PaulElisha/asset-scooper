# AssetScooper

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)  
[![Version](https://img.shields.io/badge/Version-2.0.0-green.svg)](https://github.com/your-repo/asset-scooper)  
[![Tests](https://github.com/your-repo/asset-scooper/actions/workflows/tests.yml/badge.svg)](https://github.com/your-repo/asset-scooper/actions)  
[![Discord](https://img.shields.io/discord/your-discord-server)](https://discord.gg/your-invite-link)  
[![Twitter](https://img.shields.io/twitter/follow/your-handle)](https://twitter.com/your-handle)

AssetScooper is a smart contract designed to streamline **batch swaps** on Uniswap V3, leveraging **Permit2** for gas-efficient token approvals. It enables users to swap multiple tokens into a single output token in a single transaction, making it ideal for portfolio consolidation, liquidity provision, and arbitrage strategies.

---

## Features

- **Batch Swaps**: Swap multiple tokens into a single output token in one transaction.
- **Permit2 Integration**: Eliminate the need for multiple token approvals with off-chain signatures.
- **Gas Efficiency**: Reduce gas costs by bundling swaps into a single multicall.
- **Protocol Fees**: A small fee is deducted to sustain the protocol.
- **Security**: Built with reentrancy protection, deadline enforcement, and pausable functionality.

---

## How It Works

AssetScooper simplifies the process of swapping multiple tokens by combining the power of **Uniswap V3**, **Permit2**, and **multicall**. Here’s a step-by-step breakdown:

1. **User Initiates Swap**: The user specifies the input tokens, output token, minimum amounts, and a deadline.
2. **Permit2 Signature**: The user signs a Permit2 permit, granting AssetScooper permission to transfer their tokens.
3. **Token Transfer**: AssetScooper transfers the tokens from the user’s wallet using Permit2.
4. **Batch Swap Execution**: AssetScooper constructs a multicall payload and executes the swaps on Uniswap V3.
5. **Fee Deduction & Output Transfer**: A protocol fee is deducted, and the remaining output tokens are sent to the user.

---

## Getting Started

### Prerequisites

- Node.js (v16 or higher)
- Hardhat or Foundry (for local testing)
- Ethers.js or Web3.js (for interaction)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/asset-scooper.git
   cd asset-scooper
   ```

2. Install dependencies:
    ```bash
    npm install
    ```
3. Compile the contract:
    ```bash
    npx hardhat compile
    ```

### Testing

Run the test suite to ensure everything works as expected:

    ```bash
    npx hardhat test
    ```

---

## Usage

### Deploying the Contract

1. Set up your `.env` file with the following variables:
```bash
PRIVATE_KEY=your-private-key
INFURA_API_KEY=your-infura-key
ETHERSCAN_API_KEY=your-etherscan-key
```

2. Deploy the contract to your desired network:
```bash
npx hardhat run scripts/deploy.js --network mainnet
```

### Interacting with AssetScooper

1. **Initialize a Swap**:
Prepare the swap parameters, including the input tokens, output token, minimum amounts, and deadline.
2. **Sign the Permit2 Permit**:
Use a wallet or SDK to sign the Permit2 permit.
3. **Execute the Swap**:
Call the `sweepAsset` function on the AssetScooper contract with the signed permit and swap parameters.
Example:

```solidity
IAssetScooper.SwapParam memory param = IAssetScooper.SwapParam({
    assets: [token1, token2],
    tokenOut: USDC,
    minOutputAmounts: [minAmount1, minAmount2],
    deadline: block.timestamp + 3600
});

ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom({
    permitted: [
        ISignatureTransfer.TokenPermissions({ token: token1, amount: amount1 }),
        ISignatureTransfer.TokenPermissions({ token: token2, amount: amount2 })
    ],
    nonce: nonce,
    deadline: block.timestamp + 3600
});

bytes memory signature = signPermit2Permit(permit, userPrivateKey);

assetScooper.sweepAsset(param, permit, signature, userAddress);
```

---

## Protocol Fees

AssetScooper deducts a small protocol fee from the output tokens. The fee is calculated as:

```bash
Protocol Fee = (Output Balance * PROTOCOL_FEE_BPS) / 10,000
```

The fee is sent to the `protocolFeeRecipient` address specified during deployment.

---

## Security

AssetScooper is built with security in mind:

- **Reentrancy Protection**: Uses OpenZeppelin’s `ReentrancyGuard`.
- **Deadline Enforcement**: Ensures swaps are executed within a specified time frame.
- **Pausable**: The contract owner can pause the contract in case of emergencies.

---

## Contributing

We welcome contributions from the community! To contribute:

1. Fork the repository.
2. Create a new branch for your feature or bugfix.
3. Submit a pull request with a detailed description of your changes.

Please ensure your code follows our coding standards and includes tests for new features.

---

## License

AssetScooper is licensed under the **MIT License**. See LICENSE for more details.

---

## Community

Join the conversation and stay updated:

- Discord
- Twitter
- GitHub Issues

---

Acknowledgments

- **Uniswap**: For the revolutionary decentralized exchange protocol.
- **Permit2**: For simplifying token approvals.
- **OpenZeppelin**: For providing secure and audited smart contract libraries.

---

## Disclaimer

AssetScooper is provided "as is" without warranty of any kind. Use at your own risk. Always conduct your own research and consult with a professional before engaging in DeFi activities.

## Happy Swapping! 🚀