# Cross-Chain Donation Workflow Demo Guide

This guide shows you how to demonstrate the complete cross-chain donation workflow for your pitch.

## Prerequisites

1. Contracts deployed (see `DEPLOYMENT.md`)
2. Environment variables set:
   - `PRIVATE_KEY` - Your wallet private key
   - `ETHEREUM_SEPOLIA_RPC_URL` - Ethereum Sepolia RPC
   - `ARBITRUM_SEPOLIA_RPC_URL` - Arbitrum Sepolia RPC
3. Have native tokens (ETH) on Ethereum Sepolia for gas
4. **Note**: The script will automatically request test tokens (CCIP-BnM) from the faucet if your balance is insufficient!

## Quick Demo Commands

### Step 1: Send Donation (Source Chain - Ethereum Sepolia)

```bash
source .env && forge script script/DonateWorkflow.s.sol:DonateWorkflow \
  --rpc-url ethereumSepolia \
  --broadcast \
  -vvvv \
  --sig "run(address,uint8,uint8,address,address,address,address,uint256,string)" \
  ${DONATION_SENDER_ADDRESS} \
  0 \
  2 \
  ${DONATION_RECEIVER_ADDRESS} \
  ${BADGE_NFT_ADDRESS} \
  0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05 \
  ${TREASURY_ADDRESS} \
  100000000000000000 \
  "campaign-001"
```

**Parameters:**
- `DONATION_SENDER_ADDRESS` - DonationSender contract address (from deployment)
- `0` - Ethereum Sepolia (source chain enum)
- `2` - Arbitrum Sepolia (destination chain enum)
- `DONATION_RECEIVER_ADDRESS` - DonationReceiver contract address
- `BADGE_NFT_ADDRESS` - ImpactBadgeNFT contract address
- `0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05` - CCIP-BnM token on Ethereum Sepolia
- `TREASURY_ADDRESS` - Treasury address
- `100000000000000000` - Donation amount (0.1 tokens with 18 decimals)
- `"campaign-001"` - Campaign identifier

### Step 2: Check Badge Status (Destination Chain - Arbitrum Sepolia)

Wait 1-2 minutes for CCIP to process, then check:

```bash
source .env && forge script script/DonateWorkflow.s.sol:CheckBadge \
  --rpc-url arbitrumSepolia \
  -vvv \
  --sig "run(address,address,uint256)" \
  ${BADGE_NFT_ADDRESS} \
  ${YOUR_ADDRESS} \
  0
```

**Parameters:**
- `BADGE_NFT_ADDRESS` - ImpactBadgeNFT contract address
- `YOUR_ADDRESS` - Your donor address
- `0` - Badge token ID (0 for first badge, 1 for second, etc.)

### Step 3: Verify Treasury Received Tokens

```bash
source .env && forge script script/DonateWorkflow.s.sol:CheckTreasury \
  --rpc-url arbitrumSepolia \
  -vvv \
  --sig "run(address,address,uint256)" \
  0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D \
  ${TREASURY_ADDRESS} \
  100000000000000000
```

**Parameters:**
- `0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D` - CCIP-BnM token on Arbitrum Sepolia
- `TREASURY_ADDRESS` - Treasury address
- `100000000000000000` - Expected donation amount (0.1 tokens with 18 decimals)

## Demo Script (All-in-One)

Create a `.env` file with your addresses:

```bash
# .env file
export PRIVATE_KEY="your_private_key"
export DONATION_SENDER_ADDRESS="0x..."
export DONATION_RECEIVER_ADDRESS="0x..."
export BADGE_NFT_ADDRESS="0x..."
export TREASURY_ADDRESS="0x..."
export YOUR_ADDRESS="0x..."
```

Then run the demo script:

```bash
chmod +x demo.sh
./demo.sh
```

## Frontend Integration Guide

### 1. Connect Wallet
```javascript
// Using ethers.js or viem
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const donorAddress = await signer.getAddress();
```

### 2. Check Token Balance
```javascript
const tokenContract = new ethers.Contract(
  tokenAddress,
  ['function balanceOf(address) view returns (uint256)'],
  signer
);
const balance = await tokenContract.balanceOf(donorAddress);
```

### 3. Approve Tokens
```javascript
const tokenContract = new ethers.Contract(
  tokenAddress,
  [
    'function approve(address spender, uint256 amount) returns (bool)',
    'function allowance(address owner, address spender) view returns (uint256)'
  ],
  signer
);

// Check current allowance
const allowance = await tokenContract.allowance(donorAddress, donationSenderAddress);

if (allowance < donationAmount) {
  const tx = await tokenContract.approve(donationSenderAddress, donationAmount);
  await tx.wait();
  console.log('Tokens approved!');
}
```

### 4. Send Donation
```javascript
const donationSender = new ethers.Contract(
  donationSenderAddress,
  [
    'function sendDonation(uint64 destinationChainSelector, address receiver, address token, uint256 amount, string calldata campaignId) payable returns (bytes32)'
  ],
  signer
);

// Estimate fees first
const fees = await donationSender.router.getFee(
  destinationChainSelector,
  {
    receiver: ethers.AbiCoder.defaultAbiCoder().encode(['address'], [donationReceiverAddress]),
    data: ethers.AbiCoder.defaultAbiCoder().encode(['address', 'string', 'uint256'], [donorAddress, campaignId, donationAmount]),
    tokenAmounts: [{ token: tokenAddress, amount: donationAmount }],
    extraArgs: '0x',
    feeToken: ethers.ZeroAddress
  }
);

// Send donation
const tx = await donationSender.sendDonation(
  destinationChainSelector,
  donationReceiverAddress,
  tokenAddress,
  donationAmount,
  campaignId,
  { value: fees }
);

const receipt = await tx.wait();
const messageId = receipt.logs.find(log => {
  // Parse DonationSent event
  // event DonationSent(bytes32 indexed messageId, ...)
}).args.messageId;

console.log('Donation sent! Message ID:', messageId);
```

### 5. Monitor CCIP Status
```javascript
// Use CCIP Explorer or Chainlink's CCIP monitoring
const ccipExplorerUrl = `https://ccip.chain.link/msg/${messageId}`;
console.log('Track transaction:', ccipExplorerUrl);
```

### 6. Check Badge (After CCIP Finalizes)
```javascript
// Switch to destination chain
const badgeNFT = new ethers.Contract(
  badgeNFTAddress,
  [
    'function ownerOf(uint256 tokenId) view returns (address)',
    'function donationAmount(uint256 tokenId) view returns (uint256)',
    'function campaignId(uint256 tokenId) view returns (string)',
    'function totalSupply() view returns (uint256)'
  ],
  signer
);

const totalSupply = await badgeNFT.totalSupply();
const badgeTokenId = totalSupply - 1; // Latest badge

const owner = await badgeNFT.ownerOf(badgeTokenId);
const amount = await badgeNFT.donationAmount(badgeTokenId);
const campaign = await badgeNFT.campaignId(badgeTokenId);

console.log('Badge Info:', { owner, amount, campaign });
```

## Demo Flow Summary

1. **Setup** (5 seconds)
   - Show wallet connected
   - Display token balance

2. **Approve** (10 seconds)
   - Click "Approve" button
   - Show transaction confirmation

3. **Donate** (15 seconds)
   - Enter donation amount
   - Select campaign
   - Click "Donate"
   - Show CCIP message ID

4. **Wait** (30-60 seconds)
   - Show "Processing..." status
   - Display CCIP Explorer link
   - Explain cross-chain bridge

5. **Verify** (10 seconds)
   - Show NFT badge minted
   - Display badge metadata
   - Show treasury balance increased

**Total Demo Time: ~2 minutes**

## Tips for Pitch

1. **Start with the problem**: "Donations are siloed per chain"
2. **Show the solution**: "One platform, any chain"
3. **Demonstrate**: Run the workflow script
4. **Highlight innovation**: 
   - Cross-chain NFT badges
   - Programmable token transfers
   - Automatic treasury forwarding
5. **End with impact**: "Enable global giving without barriers"

## Troubleshooting

- **Insufficient token balance**: The script automatically requests tokens from the CCIP-BnM faucet. If it still fails, manually run:
  ```bash
  forge script script/Faucet.s.sol:Faucet --rpc-url ethereumSepolia --broadcast --sig 'run(uint8)' 0
  ```

- **Transaction fails silently**: The script now:
  - Estimates CCIP fees accurately before sending
  - Uses calculated fees (estimated + 10% buffer) instead of hardcoded 0.1 ETH
  - Verifies token transfer succeeded
  - Shows detailed balance information at each step
  - If transaction fails, check the error message for specific issues

- **"InsufficientFeeTokenAmount" error**: 
  - The script now calculates fees dynamically
  - Make sure you have enough ETH (usually 0.1-0.2 ETH is sufficient)
  - Check the estimated fees in the script output

- **CCIP not finalizing**: Check CCIP Explorer for status using the message ID shown in output

- **Badge not minted**: Wait longer (CCIP can take 1-2 minutes)

- **Wrong chain**: Make sure you're on the correct network

- **Tokens not deducted**: Check if approval transaction succeeded. The script verifies this automatically.

