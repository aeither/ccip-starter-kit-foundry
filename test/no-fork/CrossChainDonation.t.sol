// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {
    CCIPLocalSimulator,
    IRouterClient,
    BurnMintERC677Helper
} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {DonationSender} from "../../src/cross-chain-donation/DonationSender.sol";
import {DonationReceiver} from "../../src/cross-chain-donation/DonationReceiver.sol";
import {ImpactBadgeNFT} from "../../src/cross-chain-donation/ImpactBadgeNFT.sol";

/**
 * @title CrossChainDonationTest
 * @notice Test suite for cross-chain donation platform with NFT badges
 * @dev Demonstrates the full flow: donation -> cross-chain transfer -> NFT minting
 */
contract CrossChainDonationTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    DonationSender public donationSender;
    DonationReceiver public donationReceiver;
    ImpactBadgeNFT public badgeNFT;

    address public alice;
    address public treasury;
    uint64 public destinationChainSelector;
    BurnMintERC677Helper public ccipBnMToken;

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();
        (uint64 chainSelector, IRouterClient sourceRouter,,,, BurnMintERC677Helper ccipBnM,) =
            ccipLocalSimulator.configuration();

        alice = makeAddr("alice");
        treasury = makeAddr("treasury");

        // Deploy NFT contract
        badgeNFT = new ImpactBadgeNFT(
            "Impact Badge",
            "IMPACT",
            "https://ipfs.io/ipfs/QmImpactBadge/"
        );

        // Deploy receiver (destination chain)
        donationReceiver = new DonationReceiver(
            address(sourceRouter),
            address(badgeNFT),
            treasury
        );

        // Transfer NFT ownership to receiver
        badgeNFT.transferOwnership(address(donationReceiver));

        // Deploy sender (source chain)
        donationSender = new DonationSender(address(sourceRouter));

        destinationChainSelector = chainSelector;
        ccipBnMToken = ccipBnM;
    }

    function test_crossChainDonationWithBadgeMinting() external {
        // Setup: Give Alice tokens and native tokens for fees
        ccipBnMToken.drip(alice);
        deal(alice, 1 ether); // Native tokens for CCIP fees
        uint256 donationAmount = 100;

        uint256 aliceBalanceBefore = ccipBnMToken.balanceOf(alice);
        uint256 treasuryBalanceBefore = ccipBnMToken.balanceOf(treasury);
        uint256 badgeCountBefore = badgeNFT.totalSupply();

        // Alice approves tokens
        vm.startPrank(alice);
        ccipBnMToken.approve(address(donationSender), donationAmount);
        vm.stopPrank();

        // Alice sends donation
        vm.startPrank(alice);
        donationSender.sendDonation{value: 0.1 ether}(
            destinationChainSelector,
            address(donationReceiver),
            address(ccipBnMToken),
            donationAmount,
            "campaign-001"
        );
        vm.stopPrank();

        // Verify balances
        uint256 aliceBalanceAfter = ccipBnMToken.balanceOf(alice);
        uint256 treasuryBalanceAfter = ccipBnMToken.balanceOf(treasury);
        uint256 badgeCountAfter = badgeNFT.totalSupply();

        // Assertions
        assertEq(aliceBalanceAfter, aliceBalanceBefore - donationAmount, "Alice balance should decrease");
        assertEq(treasuryBalanceAfter, treasuryBalanceBefore + donationAmount, "Treasury should receive tokens");
        assertEq(badgeCountAfter, badgeCountBefore + 1, "Badge should be minted");

        // Verify NFT ownership
        uint256 badgeTokenId = badgeCountAfter - 1;
        assertEq(badgeNFT.ownerOf(badgeTokenId), alice, "Alice should own the badge");
        assertEq(badgeNFT.donationAmount(badgeTokenId), donationAmount, "Badge should record donation amount");
        assertEq(badgeNFT.campaignId(badgeTokenId), "campaign-001", "Badge should record campaign ID");
    }

    function test_multipleDonationsFromSameDonor() external {
        // Setup
        ccipBnMToken.drip(alice);
        deal(alice, 2 ether); // Native tokens for CCIP fees

        uint256 donation1 = 50;
        uint256 donation2 = 75;

        // First donation
        vm.startPrank(alice);
        ccipBnMToken.approve(address(donationSender), donation1 + donation2);
        donationSender.sendDonation{value: 0.1 ether}(
            destinationChainSelector,
            address(donationReceiver),
            address(ccipBnMToken),
            donation1,
            "campaign-001"
        );
        vm.stopPrank();

        // Second donation
        vm.startPrank(alice);
        donationSender.sendDonation{value: 0.1 ether}(
            destinationChainSelector,
            address(donationReceiver),
            address(ccipBnMToken),
            donation2,
            "campaign-002"
        );
        vm.stopPrank();

        // Verify both badges were minted
        assertEq(badgeNFT.totalSupply(), 2, "Should have 2 badges");
        assertEq(badgeNFT.ownerOf(0), alice, "Alice should own first badge");
        assertEq(badgeNFT.ownerOf(1), alice, "Alice should own second badge");
        assertEq(badgeNFT.donationAmount(0), donation1, "First badge should record first donation");
        assertEq(badgeNFT.donationAmount(1), donation2, "Second badge should record second donation");
    }

    function test_donationFromDifferentDonors() external {
        address bob = makeAddr("bob");
        
        // Setup
        ccipBnMToken.drip(alice);
        ccipBnMToken.drip(bob);
        deal(alice, 1 ether); // Native tokens for CCIP fees
        deal(bob, 1 ether); // Native tokens for CCIP fees

        uint256 aliceDonation = 100;
        uint256 bobDonation = 200;

        // Alice's donation
        vm.startPrank(alice);
        ccipBnMToken.approve(address(donationSender), aliceDonation);
        donationSender.sendDonation{value: 0.1 ether}(
            destinationChainSelector,
            address(donationReceiver),
            address(ccipBnMToken),
            aliceDonation,
            "campaign-001"
        );
        vm.stopPrank();

        // Bob's donation
        vm.startPrank(bob);
        ccipBnMToken.approve(address(donationSender), bobDonation);
        donationSender.sendDonation{value: 0.1 ether}(
            destinationChainSelector,
            address(donationReceiver),
            address(ccipBnMToken),
            bobDonation,
            "campaign-001"
        );
        vm.stopPrank();

        // Verify both badges
        assertEq(badgeNFT.totalSupply(), 2, "Should have 2 badges");
        assertEq(badgeNFT.ownerOf(0), alice, "Alice should own badge 0");
        assertEq(badgeNFT.ownerOf(1), bob, "Bob should own badge 1");
        assertEq(badgeNFT.donationAmount(0), aliceDonation, "Badge 0 should record Alice's donation");
        assertEq(badgeNFT.donationAmount(1), bobDonation, "Badge 1 should record Bob's donation");
    }
}

