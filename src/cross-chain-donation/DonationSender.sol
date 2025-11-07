// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/utils/SafeERC20.sol";
import {OwnerIsCreator} from "../../lib/chainlink-evm/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";

/**
 * @title DonationSender
 * @notice Sends cross-chain donations with metadata
 * @dev Based on Example04 (ProgrammableTokenTransfers) pattern
 */
contract DonationSender is OwnerIsCreator {
    using SafeERC20 for IERC20;

    error InsufficientFeeTokenAmount();
    error InsufficientTokenBalance();

    event DonationSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed donor,
        address token,
        uint256 amount,
        string campaignId
    );

    IRouterClient public immutable router;

    constructor(address router_) {
        router = IRouterClient(router_);
    }

    receive() external payable {}

    /**
     * @notice Send a cross-chain donation
     * @param destinationChainSelector The destination chain selector
     * @param receiver The donation receiver contract address
     * @param token The token address to donate
     * @param amount The donation amount
     * @param campaignId The campaign identifier
     * @return messageId The CCIP message ID
     */
    function sendDonation(
        uint64 destinationChainSelector,
        address receiver,
        address token,
        uint256 amount,
        string calldata campaignId
    ) external payable returns (bytes32 messageId) {
        // Check token balance
        uint256 balance = IERC20(token).balanceOf(msg.sender);
        if (balance < amount) revert InsufficientTokenBalance();

        // Prepare token amounts
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        // Encode donation metadata
        bytes memory data = abi.encode(msg.sender, campaignId, amount);

        // Create CCIP message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: data,
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: 300_000,
                    allowOutOfOrderExecution: false
                })
            ),
            feeToken: address(0) // Pay fees in native token
        });

        // Get fees
        uint256 fees = router.getFee(destinationChainSelector, evm2AnyMessage);
        if (msg.value < fees) revert InsufficientFeeTokenAmount();

        // Approve router to spend tokens
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).safeApprove(address(router), amount);

        // Send CCIP message
        messageId = router.ccipSend{value: fees}(destinationChainSelector, evm2AnyMessage);

        emit DonationSent(messageId, destinationChainSelector, msg.sender, token, amount, campaignId);

        return messageId;
    }
}

