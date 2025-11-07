// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "./Helper.sol";
import {ImpactBadgeNFT} from "../src/cross-chain-donation/ImpactBadgeNFT.sol";
import {DonationReceiver} from "../src/cross-chain-donation/DonationReceiver.sol";
import {DonationSender} from "../src/cross-chain-donation/DonationSender.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";

interface ICCIPToken {
    function drip(address to) external;
}

/**
 * @title DeployDestination
 * @notice Deploys ImpactBadgeNFT and DonationReceiver on destination chain
 * @dev Run this on the destination chain (e.g., Arbitrum Sepolia)
 */
contract DeployDestination is Script, Helper {
    function run(SupportedNetworks destination, address treasury) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address router, , , ) = getConfigFromNetwork(destination);

        // Deploy NFT contract
        ImpactBadgeNFT badgeNFT = new ImpactBadgeNFT(
            "Impact Badge",
            "IMPACT",
            "https://ipfs.io/ipfs/QmImpactBadge/"
        );

        console.log(
            "ImpactBadgeNFT deployed on",
            networks[destination],
            "at address:",
            address(badgeNFT)
        );

        // Deploy DonationReceiver
        DonationReceiver donationReceiver = new DonationReceiver(
            router,
            address(badgeNFT),
            treasury
        );

        console.log(
            "DonationReceiver deployed on",
            networks[destination],
            "at address:",
            address(donationReceiver)
        );

        // Transfer NFT ownership to receiver
        badgeNFT.transferOwnership(address(donationReceiver));

        console.log("NFT ownership transferred to DonationReceiver:", address(donationReceiver));
        console.log("Treasury address:", treasury);

        vm.stopBroadcast();
    }
}

/**
 * @title DeploySource
 * @notice Deploys DonationSender on source chain
 * @dev Run this on the source chain (e.g., Ethereum Sepolia)
 */
contract DeploySource is Script, Helper {
    function run(SupportedNetworks source) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address router, , , ) = getConfigFromNetwork(source);

        // Deploy DonationSender
        DonationSender donationSender = new DonationSender(router);

        console.log(
            "DonationSender deployed on",
            networks[source],
            "at address:",
            address(donationSender)
        );

        vm.stopBroadcast();
    }
}

/**
 * @title DonateWorkflow
 * @notice Complete donation workflow with automatic token requests and fee estimation
 * @dev Handles token balance checking, faucet requests, and dynamic fee calculation
 */
contract DonateWorkflow is Script, Helper {
    function run(
        address payable donationSenderAddress,
        SupportedNetworks source,
        SupportedNetworks destination,
        address donationReceiverAddress,
        address token,
        uint256 amount,
        string memory campaignId
    ) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        address donorAddress = vm.addr(senderPrivateKey);
        
        console.log("\n=== Starting Donation Workflow ===");
        console.log("Donor address:", donorAddress);
        console.log("Source chain:", networks[source]);
        console.log("Destination chain:", networks[destination]);
        console.log("Campaign ID:", campaignId);
        console.log("Donation amount:", amount);
        
        // Check token balance
        {
            uint256 tokenBalance = IERC20(token).balanceOf(donorAddress);
            console.log("\n--- Token Balance Check ---");
            console.log("Current balance:", tokenBalance);
            console.log("Required amount:", amount);
            
            if (tokenBalance < amount) {
                console.log("\n!!! Insufficient balance. Requesting tokens from faucet...");
                vm.startBroadcast(senderPrivateKey);
                (address ccipBnm,) = getDummyTokensFromNetwork(source);
                ICCIPToken(ccipBnm).drip(donorAddress);
                vm.stopBroadcast();
                
                tokenBalance = IERC20(token).balanceOf(donorAddress);
                console.log("New balance after faucet:", tokenBalance);
                require(tokenBalance >= amount, "Insufficient token balance");
            }
        }
        
        // Get destination chain selector and estimate fees
        (, , , uint64 destinationChainSelector) = getConfigFromNetwork(destination);
        uint256 feesWithBuffer;
        
        {
            console.log("\n--- Fee Estimation ---");
            Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});
            
            Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
                receiver: abi.encode(donationReceiverAddress),
                data: abi.encode(donorAddress, campaignId, amount),
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(
                    Client.GenericExtraArgsV2({gasLimit: 300_000, allowOutOfOrderExecution: false})
                ),
                feeToken: address(0)
            });
            
            (address router, , , ) = getConfigFromNetwork(source);
            feesWithBuffer = (IRouterClient(router).getFee(destinationChainSelector, evm2AnyMessage) * 110) / 100;
            
            console.log("Fees with 10%% buffer:", feesWithBuffer);
            console.log("Donor ETH balance:", donorAddress.balance);
            require(donorAddress.balance >= feesWithBuffer, "Insufficient ETH for fees");
        }
        
        // Approve and send donation
        console.log("\n--- Token Approval ---");
        vm.startBroadcast(senderPrivateKey);
        
        if (IERC20(token).allowance(donorAddress, donationSenderAddress) < amount) {
            IERC20(token).approve(donationSenderAddress, amount);
            console.log("Approved", amount, "tokens");
        }
        
        console.log("\n--- Sending Donation ---");
        console.log("Donor token balance before:", IERC20(token).balanceOf(donorAddress));
        
        bytes32 messageId = DonationSender(donationSenderAddress).sendDonation{value: feesWithBuffer}(
            destinationChainSelector,
            donationReceiverAddress,
            token,
            amount,
            campaignId
        );
        
        vm.stopBroadcast();
        
        console.log("Donor token balance after:", IERC20(token).balanceOf(donorAddress));
        console.log("\n=== Donation Sent Successfully! ===");
        console.log("Message ID:", vm.toString(messageId));
        console.log("\nTrack your transaction at:");
        console.log(string.concat("https://ccip.chain.link/msg/", vm.toString(messageId)));
        console.log("\nNext steps:");
        console.log("1. Wait 1-2 minutes for CCIP to process");
        console.log("2. Check badge status on", networks[destination]);
    }
}

/**
 * @title CheckBadge
 * @notice Check badge NFT details after donation
 * @dev Run this on the destination chain after CCIP finalizes
 */
contract CheckBadge is Script, Helper {
    function run(
        address badgeNFTAddress,
        address donorAddress,
        uint256 tokenId
    ) external view {
        ImpactBadgeNFT badgeNFT = ImpactBadgeNFT(badgeNFTAddress);
        
        console.log("\n=== Badge Status Check ===");
        console.log("Badge NFT address:", badgeNFTAddress);
        console.log("Token ID:", tokenId);
        
        try badgeNFT.ownerOf(tokenId) returns (address owner) {
            console.log("\n--- Badge Found! ---");
            console.log("Owner:", owner);
            console.log("Expected owner:", donorAddress);
            
            if (owner == donorAddress) {
                console.log("[SUCCESS] Badge correctly minted to donor");
            } else {
                console.log("[ERROR] Badge owner mismatch!");
            }
            
            uint256 amount = badgeNFT.donationAmount(tokenId);
            string memory campaignId = badgeNFT.campaignId(tokenId);
            
            console.log("\n--- Badge Details ---");
            console.log("Donation amount:", amount);
            console.log("Campaign ID:", campaignId);
            
            string memory tokenURI = badgeNFT.tokenURI(tokenId);
            console.log("Token URI:", tokenURI);
            
            uint256 totalSupply = badgeNFT.totalSupply();
            console.log("\nTotal badges minted:", totalSupply);
            
        } catch {
            console.log("\n[NOT FOUND] Badge not found!");
            console.log("Possible reasons:");
            console.log("- CCIP transaction still processing (wait 1-2 minutes)");
            console.log("- Wrong token ID");
            console.log("- Transaction failed");
            
            uint256 totalSupply = badgeNFT.totalSupply();
            console.log("\nTotal badges minted:", totalSupply);
            if (totalSupply > 0) {
                console.log("Try checking token ID:", totalSupply - 1);
            }
        }
    }
}

/**
 * @title CheckTreasury
 * @notice Verify treasury received the donation tokens
 * @dev Run this on the destination chain after CCIP finalizes
 */
contract CheckTreasury is Script, Helper {
    function run(
        address token,
        address treasury,
        uint256 expectedAmount
    ) external view {
        console.log("\n=== Treasury Status Check ===");
        console.log("Token address:", token);
        console.log("Treasury address:", treasury);
        
        uint256 treasuryBalance = IERC20(token).balanceOf(treasury);
        
        console.log("\n--- Treasury Balance ---");
        console.log("Current balance:", treasuryBalance);
        console.log("Expected minimum:", expectedAmount);
        
        if (treasuryBalance >= expectedAmount) {
            console.log("\n[SUCCESS] Treasury has received the tokens!");
            console.log("Total tokens in treasury:", treasuryBalance);
        } else {
            console.log("\n[WARNING] Treasury balance lower than expected");
            console.log("This could mean:");
            console.log("- CCIP transaction still processing");
            console.log("- Tokens were previously withdrawn");
            console.log("- Transaction failed");
        }
    }
}

