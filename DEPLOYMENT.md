# Cross-Chain Donation Platform Deployment Guide

## Overview
Deploy the cross-chain donation platform to Ethereum Sepolia (source) and Arbitrum Sepolia (destination).

## Prerequisites
1. Set your `PRIVATE_KEY` environment variable
2. Set `ETHEREUM_SEPOLIA_RPC_URL` environment variable
3. Set `ARBITRUM_SEPOLIA_RPC_URL` environment variable
4. Have native tokens (ETH) on both chains for gas
5. Have LINK tokens on source chain for CCIP fees (optional, can use native)

## Deployment Steps

### Step 1: Deploy on Destination Chain (Arbitrum Sepolia)
Deploy the NFT contract and DonationReceiver on Arbitrum Sepolia:

```bash
source .env && forge script script/CrossChainDonation.s.sol:DeployDestination \
  --rpc-url arbitrumSepolia \
  --broadcast \
  --verify \
  -vvvv \
  --sig "run(uint8,address)" \
  2 ${PUBLIC_KEY}
```

**Parameters:**
- `2` = Arbitrum Sepolia (enum value from Helper.sol)
- `0xYourTreasuryAddress` = Address that will receive donated tokens

**Expected Output:**
- ImpactBadgeNFT contract address
- DonationReceiver contract address

### Step 2: Deploy on Source Chain (Ethereum Sepolia)
Deploy the DonationSender on Ethereum Sepolia:

```bash
forge script script/CrossChainDonation.s.sol:DeploySource \
  --rpc-url ethereumSepolia \
  --broadcast \
  --verify \
  -vvvv \
  --sig "run(uint8)" \
  0
```

**Parameters:**
- `0` = Ethereum Sepolia (enum value from Helper.sol)

**Expected Output:**
- DonationSender contract address

### Step 3: Send Test Donation (Full Workflow)
After deployment, send a donation using the complete workflow. This script automatically:
- Checks your token balance
- Requests test tokens from faucet if needed
- Estimates CCIP fees dynamically
- Approves tokens
- Sends the donation
- Verifies the transfer

```bash
source .env && forge script script/CrossChainDonation.s.sol:DonateWorkflow \
  --rpc-url ethereumSepolia \
  --broadcast \
  -vvvv \
  --sig "run(address,uint8,uint8,address,address,uint256,string)" \
  ${DONATION_SENDER_ADDRESS} \
  0 \
  2 \
  ${DONATION_RECEIVER_ADDRESS} \
  0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05 \
  100000000000000000 \
  "campaign-001"
```

**Parameters:**
- `DONATION_SENDER_ADDRESS` = DonationSender address from Step 2
- `0` = Ethereum Sepolia (source chain)
- `2` = Arbitrum Sepolia (destination chain)
- `DONATION_RECEIVER_ADDRESS` = DonationReceiver address from Step 1
- `0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05` = CCIP-BnM token on Ethereum Sepolia
- `100000000000000000` = Donation amount (0.1 tokens with 18 decimals)
- `"campaign-001"` = Campaign identifier

### Step 4: Check Badge Status (After 1-2 minutes)
Verify the NFT badge was minted to the donor on Arbitrum Sepolia:

```bash
source .env && forge script script/CrossChainDonation.s.sol:CheckBadge \
  --rpc-url arbitrumSepolia \
  -vvv \
  --sig "run(address,address,uint256)" \
  ${BADGE_NFT_ADDRESS} \
  ${YOUR_ADDRESS} \
  0
```

**Parameters:**
- `BADGE_NFT_ADDRESS` = ImpactBadgeNFT address from Step 1
- `YOUR_ADDRESS` = Your donor wallet address
- `0` = Badge token ID (0 for first badge, increment for subsequent badges)

### Step 5: Verify Treasury Balance
Confirm the treasury received the donation tokens on Arbitrum Sepolia:

```bash
source .env && forge script script/CrossChainDonation.s.sol:CheckTreasury \
  --rpc-url arbitrumSepolia \
  -vvv \
  --sig "run(address,address,uint256)" \
  0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D \
  ${TREASURY_ADDRESS} \
  100000000000000000
```

**Parameters:**
- `0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D` = CCIP-BnM token on Arbitrum Sepolia
- `TREASURY_ADDRESS` = Treasury address
- `100000000000000000` = Expected donation amount (0.1 tokens)

## Network Enum Values
- `0` = ETHEREUM_SEPOLIA
- `2` = ARBITRUM_SEPOLIA

## Contract Addresses Reference

### Ethereum Sepolia
- Router: `0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59`
- LINK: `0x779877A7B0D9E8603169DdbD7836e478b4624789`
- CCIP-BnM: `0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05`

### Arbitrum Sepolia
- Router: `0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165`
- LINK: `0xb1D4538B4571d411F07960EF2838Ce337FE1E80E`
- CCIP-BnM: `0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D`

## Notes
- Make sure to fund the DonationSender contract with native tokens for CCIP fees
- Donors need to approve tokens to DonationSender before sending donations
- NFT badges are automatically minted to donors on the destination chain
- All donated tokens are forwarded to the treasury address

