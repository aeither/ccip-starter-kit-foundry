// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ImpactBadgeNFT
 * @notice NFT contract for donor recognition badges
 * @dev Mints badges to donors when they make cross-chain donations
 */
contract ImpactBadgeNFT is ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter;
    string private _baseTokenURI;

    // Mapping from tokenId to donation amount
    mapping(uint256 => uint256) public donationAmount;
    // Mapping from tokenId to campaign ID
    mapping(uint256 => string) public campaignId;

    event BadgeMinted(address indexed donor, uint256 indexed tokenId, uint256 amount, string campaignId);

    constructor(string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) {
        _baseTokenURI = baseURI;
    }

    /**
     * @notice Mint a badge to a donor
     * @param to The donor address
     * @param amount The donation amount
     * @param campaignId_ The campaign identifier
     */
    function mintBadge(address to, uint256 amount, string memory campaignId_) external onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked(_baseTokenURI, "/", _toString(tokenId))));
        
        donationAmount[tokenId] = amount;
        campaignId[tokenId] = campaignId_;

        emit BadgeMinted(to, tokenId, amount, campaignId_);
    }

    /**
     * @notice Get the total number of badges minted
     * @return The total supply of badges
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

