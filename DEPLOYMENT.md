# Cross-Chain Donation Platform Deployment Guide

## Overview
Deploy the cross-chain donation platform to Base Sepolia (source) and Ethereum Sepolia (destination).

## Prerequisites
1. Set your `PRIVATE_KEY` environment variable
2. Set `BASE_SEPOLIA_RPC_URL` environment variable
3. Set `ETHEREUM_SEPOLIA_RPC_URL` environment variable
4. Have native tokens (ETH) on both chains for gas
5. Have LINK tokens on source chain for CCIP fees (optional, can use native)

## Deployment Steps

### Step 1: Deploy on Destination Chain (Ethereum Sepolia)
Deploy the NFT contract and DonationReceiver on Ethereum Sepolia:

```bash
source .env && forge script script/CrossChainDonation.s.sol:DeployDestination \
  --rpc-url ethereumSepolia \
  --broadcast \
  --verify \
  -vvvv \
  --sig "run(uint8,address)" \
  0 ${TREASURY_ADDRESS}
```

**Parameters:**
- `0` = Ethereum Sepolia (enum value from Helper.sol)
- `TREASURY_ADDRESS` = Address that will receive donated tokens (NOT your wallet address!)

**Expected Output:**
- ImpactBadgeNFT contract address
- DonationReceiver contract address

### Step 2: Deploy on Source Chain (Base Sepolia)
Deploy the DonationSender on Base Sepolia:

```bash
forge script script/CrossChainDonation.s.sol:DeploySource \
  --rpc-url baseSepolia \
  --broadcast \
  --verify \
  -vvvv \
  --sig "run(uint8)" \
  6
```

**Parameters:**
- `6` = Base Sepolia (enum value from Helper.sol)

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
  --rpc-url baseSepolia \
  --broadcast \
  -vvvv \
  --sig "run(address,uint8,uint8,address,address,uint256,string)" \
  ${DONATION_SENDER_ADDRESS} \
  6 \
  0 \
  ${DONATION_RECEIVER_ADDRESS} \
  0x88A2d74F47a237a62e7A51cdDa67270CE381555e \
  100000000000000000 \
  "campaign-001"
```

**Parameters:**
- `DONATION_SENDER_ADDRESS` = DonationSender address from Step 2
- `6` = Base Sepolia (source chain)
- `0` = Ethereum Sepolia (destination chain)
- `DONATION_RECEIVER_ADDRESS` = DonationReceiver address from Step 1
- `0x88A2d74F47a237a62e7A51cdDa67270CE381555e` = CCIP-BnM token on Base Sepolia
- `100000000000000000` = Donation amount (0.1 tokens with 18 decimals)
- `"campaign-001"` = Campaign identifier

### Step 4: Check Badge Status (After 1-2 minutes)
Verify the NFT badge was minted to the donor on Ethereum Sepolia:

```bash
source .env && forge script script/CrossChainDonation.s.sol:CheckBadge \
  --rpc-url ethereumSepolia \
  -vvv \
  --sig "run(address,address,uint256)" \
  ${BADGE_NFT_ADDRESS} \
  ${DONOR_ADDRESS} \
  0
```

**Parameters:**
- `BADGE_NFT_ADDRESS` = ImpactBadgeNFT address from Step 1
- `DONOR_ADDRESS` = Your donor wallet address
- `0` = Badge token ID (0 for first badge, increment for subsequent badges)

### Step 5: Verify Treasury Balance
Confirm the treasury received the donation tokens on Ethereum Sepolia:

```bash
source .env && forge script script/CrossChainDonation.s.sol:CheckTreasury \
  --rpc-url ethereumSepolia \
  -vvv \
  --sig "run(address,address,uint256)" \
  0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05 \
  ${TREASURY_ADDRESS} \
  100000000000000000
```

**Parameters:**
- `0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05` = CCIP-BnM token on Ethereum Sepolia
- `TREASURY_ADDRESS` = Treasury address
- `100000000000000000` = Expected donation amount (0.1 tokens)

## Network Enum Values
- `0` = ETHEREUM_SEPOLIA
- `6` = BASE_SEPOLIA

## Contract Addresses Reference

### Base Sepolia
- Router: `0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93`
- LINK: `0xE4aB69C077896252FAFBD49EFD26B5D171A32410`
- CCIP-BnM: `0x88A2d74F47a237a62e7A51cdDa67270CE381555e`

### Ethereum Sepolia
- Router: `0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59`
- LINK: `0x779877A7B0D9E8603169DdbD7836e478b4624789`
- CCIP-BnM: `0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05`

## Notes
- Make sure to fund the DonationSender contract with native tokens for CCIP fees
- Donors need to approve tokens to DonationSender before sending donations
- NFT badges are automatically minted to donors on the destination chain
- All donated tokens are forwarded to the treasury address

## Troubleshooting

### Tokens Going to Wrong Address

**Problem**: Tokens are being received at your donor address instead of the treasury.

**Cause**: You deployed the `DonationReceiver` with your wallet address as the treasury parameter instead of the intended treasury address.

**Solution**: 
1. You need to redeploy the `DonationReceiver` contract with the correct treasury address
2. Or, call the `setTreasury()` function on the existing contract:

```bash
cast send ${DONATION_RECEIVER_ADDRESS} \
  "setTreasury(address)" ${TREASURY_ADDRESS} \
  --rpc-url ethereumSepolia \
  --private-key ${PRIVATE_KEY}
```

### How to Check Current Treasury Address

```bash
cast call ${DONATION_RECEIVER_ADDRESS} \
  "treasury()(address)" \
  --rpc-url ethereumSepolia
```
