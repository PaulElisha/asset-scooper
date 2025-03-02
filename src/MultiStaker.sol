// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
// import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
// import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
// import "@uniswap/v3-staker/contracts/interfaces/IUniswapV3Staker.sol";
// import "./interfaces/IMultiStaker.sol";

// contract MultiStaker is IMultiStaker {
//     IUniswapV3Staker public immutable staker;
//     INonfungiblePositionManager public immutable nonfungiblePositionManager;

//     // Mapping to track staked NFTs and their incentives
//     mapping(uint256 => IUniswapV3Staker.IncentiveKey[]) public stakedIncentives;

//     // Events
//     event NFTStaked(
//         uint256 indexed tokenId,
//         IUniswapV3Staker.IncentiveKey[] incentives
//     );
//     event NFTUnstaked(
//         uint256 indexed tokenId,
//         IUniswapV3Staker.IncentiveKey[] incentives
//     );
//     event RewardsClaimed(
//         address indexed recipient,
//         IERC20Minimal[] rewardTokens,
//         uint256[] amounts
//     );

//     constructor(
//         IUniswapV3Staker _staker,
//         INonfungiblePositionManager _nonfungiblePositionManager
//     ) {
//         staker = _staker;
//         nonfungiblePositionManager = _nonfungiblePositionManager;
//     }

//     function stakeNFT(
//         IUniswapV3Staker.IncentiveKey[] memory incentives,
//         uint256 tokenId
//     ) external {
//         require(incentives.length > 0, "No incentives provided");

//         // Transfer the NFT to this contract
//         nonfungiblePositionManager.safeTransferFrom(
//             msg.sender,
//             address(this),
//             tokenId
//         );

//         IUniswapV3Staker.IncentiveKey[] calldata incentives;

//         // Stake the NFT in each incentive
//         for (uint256 i; i < incentives.length; i++) {
//             abi.encodeWithSelector(
//                 IUniswapV3Staker.stakeToken.selector,
//                 incentives[i],
//                 tokenId
//             );
//             incentives[i] = staker.stakeToken(incentives[i], tokenId);
//             stakedIncentives[tokenId].push(incentives[i]);
//         }

//         emit NFTStaked(tokenId, incentives);
//     }

//     function unstakeNFT(uint256 tokenId) external {
//         IUniswapV3Staker.IncentiveKey[] memory incentives = stakedIncentives[
//             tokenId
//         ];
//         require(incentives.length > 0, "NFT not staked in any incentives");

//         // Unstake the NFT from each incentive
//         for (uint256 i = 0; i < incentives.length; i++) {
//             staker.unstakeToken(incentives[i], tokenId);
//         }

//         // Transfer the NFT back to the owner
//         nonfungiblePositionManager.safeTransferFrom(
//             address(this),
//             msg.sender,
//             tokenId
//         );

//         // Clear the staked incentives for this NFT
//         delete stakedIncentives[tokenId];

//         emit NFTUnstaked(tokenId, incentives);
//     }

//     function claimRewards(
//         uint256 tokenId,
//         IERC20Minimal[] calldata rewardTokens
//     ) external {
//         IUniswapV3Staker.IncentiveKey[] memory incentives = stakedIncentives[
//             tokenId
//         ];
//         require(incentives.length > 0, "NFT not staked in any incentives");

//         uint256[] memory amounts = new uint256[](rewardTokens.length);

//         // Claim rewards for each reward token
//         for (uint256 i = 0; i < rewardTokens.length; i++) {
//             amounts[i] = staker.claimReward(
//                 rewardTokens[i],
//                 msg.sender,
//                 type(uint256).max
//             );
//         }

//         emit RewardsClaimed(msg.sender, rewardTokens, amounts);
//     }

//     function aggregateRewards(
//         uint256 tokenId,
//         IERC20Minimal[] calldata rewardTokens
//     ) external {
//         IUniswapV3Staker.IncentiveKey[] memory incentives = stakedIncentives[
//             tokenId
//         ];
//         require(incentives.length > 0, "NFT not staked in any incentives");

//         uint256[] memory amounts = new uint256[](rewardTokens.length);

//         // Aggregate rewards for each reward token
//         for (uint256 i = 0; i < rewardTokens.length; i++) {
//             for (uint256 j = 0; j < incentives.length; j++) {
//                 amounts[i] += staker.claimReward(
//                     rewardTokens[i],
//                     msg.sender,
//                     type(uint256).max
//                 );
//             }
//         }

//         emit RewardsClaimed(msg.sender, rewardTokens, amounts);
//     }

//     function getStakedIncentives(
//         uint256 tokenId
//     ) external view returns (IUniswapV3Staker.IncentiveKey[] memory) {
//         return stakedIncentives[tokenId];
//     }
// }
