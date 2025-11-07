// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "./Helper.sol";
import {ImpactBadgeNFT} from "../src/cross-chain-donation/ImpactBadgeNFT.sol";
import {DonationReceiver} from "../src/cross-chain-donation/DonationReceiver.sol";
import {DonationSender} from "../src/cross-chain-donation/DonationSender.sol";

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
 * @title SendDonation
 * @notice Helper script to send a test donation
 * @dev Useful for testing after deployment
 */
contract SendDonation is Script, Helper {
    function run(
        address payable donationSenderAddress,
        SupportedNetworks destination,
        address donationReceiverAddress,
        address token,
        uint256 amount,
        string memory campaignId
    ) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (, , , uint64 destinationChainId) = getConfigFromNetwork(destination);

        DonationSender donationSender = DonationSender(donationSenderAddress);

        bytes32 messageId = donationSender.sendDonation{value: 0.001 ether}(
            destinationChainId,
            donationReceiverAddress,
            token,
            amount,
            campaignId
        );

        console.log("Donation sent! Message ID:", vm.toString(messageId));
        console.log("Campaign ID:", campaignId);
        console.log("Amount:", amount);

        vm.stopBroadcast();
    }
}

