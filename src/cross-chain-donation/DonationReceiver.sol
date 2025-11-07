// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/utils/SafeERC20.sol";
import {OwnerIsCreator} from "../../lib/chainlink-evm/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {ImpactBadgeNFT} from "./ImpactBadgeNFT.sol";

/**
 * @title DonationReceiver
 * @notice Receives cross-chain donations and mints NFT badges
 * @dev Combines Example04 (ProgrammableTokenTransfers) and Example07 (NFT minting) patterns
 */
contract DonationReceiver is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    ImpactBadgeNFT public immutable badgeNFT;
    address public treasury;

    event DonationReceived(
        bytes32 indexed messageId,
        address indexed donor,
        address token,
        uint256 amount,
        string campaignId,
        uint256 badgeTokenId
    );

    error InvalidTreasury();
    error MintFailed();

    constructor(address router, address badgeNFT_, address treasury_) CCIPReceiver(router) {
        if (treasury_ == address(0)) revert InvalidTreasury();
        badgeNFT = ImpactBadgeNFT(badgeNFT_);
        treasury = treasury_;
    }

    /**
     * @notice Handle incoming CCIP message
     * @dev Receives donation, forwards tokens to treasury, mints NFT badge
     */
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        bytes32 messageId = any2EvmMessage.messageId;
        
        // Decode donation metadata
        (address donor, string memory campaignId,) = 
            abi.decode(any2EvmMessage.data, (address, string, uint256));

        // Get received tokens
        Client.EVMTokenAmount[] memory tokenAmounts = any2EvmMessage.destTokenAmounts;
        address token = tokenAmounts[0].token;
        uint256 receivedAmount = tokenAmounts[0].amount;

        // Forward tokens to treasury
        IERC20(token).safeTransfer(treasury, receivedAmount);

        // Mint NFT badge to donor
        badgeNFT.mintBadge(donor, receivedAmount, campaignId);
        uint256 badgeTokenId = badgeNFT.totalSupply() - 1;

        emit DonationReceived(messageId, donor, token, receivedAmount, campaignId, badgeTokenId);
    }

    /**
     * @notice Update treasury address
     */
    function setTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert InvalidTreasury();
        treasury = treasury_;
    }
}

