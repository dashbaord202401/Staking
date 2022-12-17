// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

contract LockedStaking is
    ReentrancyGuard,
    Ownable,
    ERC721HolderUpgradeable,
    ERC1155HolderUpgradeable
{
    uint256 public fractionStakeCounter;
    uint256 public nftStakeCounter;
    uint256 public tokenStakeCounter;

    uint256 public MIN_STAKE_AMOUNT = 100;
    uint256 public STAKE_PERIOD = 365 days;

    string private constant ZERO_BAL = "Zero Balance";
    string private constant NO_CONTRIBUTION = "No Contributions";
    string private constant NEVER_CONTRIBUTED = "Address has never contributed";
    string private constant MIN_CONTRIBUTION =
        "Amount less than minimum contribution amount";

    struct tokenStaker {
        address user;
        address token;
        uint256 amount;
        uint256 joined;
        uint256 endsIn;
        bool exists;
    }

    struct nftStaker {
        address user;
        address collection;
        uint256 tokenId;
        uint256 joined;
        uint256 endsIn;
        bool exists;
    }

    struct FractionStaker {
        address user;
        address collection;
        uint256 tokenId;
        uint256 quantity;
        uint256 joined;
        uint256 endsIn;
        bool exists;
    }

    mapping(uint256 => tokenStaker) public tokenStakers;
    mapping(uint256 => nftStaker) public nftStakers;
    mapping(uint256 => FractionStaker) public fractionStakers;
    mapping(address => uint256[]) private StakedFractions;
    mapping(address => uint256[]) private StakedNfts;
    mapping(address => uint256[]) private StakedTokens;

    address[] public tokenStakerList;
    address[] public nftStakerList;
    address[] public fractionStakerList;
    address[] private auxArray;

    constructor() ReentrancyGuard() {}

    receive() external payable {}

    fallback() external payable {}

    function updateMinStake(uint256 _amount) external onlyOwner {
        require(_amount != 0, "Can't be zero");
        MIN_STAKE_AMOUNT = _amount;
    }

    function getFractionStakeData() external view returns (uint256[] memory) {
        return StakedFractions[msg.sender];
    }

    function getNftStakeData() external view returns (uint256[] memory) {
        return StakedNfts[msg.sender];
    }

    function getTokenStakeData() external view returns (uint256[] memory) {
        return StakedTokens[msg.sender];
    }

    function tokenStake(address token, uint256 amount) external nonReentrant {
        require(amount >= MIN_STAKE_AMOUNT, MIN_CONTRIBUTION);
        IERC20(token).transferFrom(msg.sender, address(this), amount);

         tokenStakers[tokenStakeCounter] = tokenStaker(
            msg.sender,
            token,
            amount,
            block.timestamp,
            block.timestamp + STAKE_PERIOD,
            true
        );
         StakedTokens[msg.sender].push(tokenStakeCounter);
        tokenStakeCounter++;
    }

    function nftStake(address _collection, uint256 _tokenId) external {
        IERC721(_collection).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        nftStakers[nftStakeCounter] = nftStaker(
            msg.sender,
            _collection,
            _tokenId,
            block.timestamp,
            block.timestamp + STAKE_PERIOD,
            true
        );
        StakedNfts[msg.sender].push(nftStakeCounter);
        nftStakeCounter++;
    }

    function fractionStake(
        address _collection,
        uint256 _tokenId,
        uint256 _quantity
    ) external {
        require(
            IERC1155(_collection).balanceOf(msg.sender, _tokenId) >= _quantity,
            "Insufficient Balance!"
        );
        IERC1155(_collection).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _quantity,
            "0x00"
        );
        fractionStakers[fractionStakeCounter] = FractionStaker(
            msg.sender,
            _collection,
            _tokenId,
            _quantity,
            block.timestamp,
            block.timestamp + STAKE_PERIOD,
            true
        );
        StakedFractions[msg.sender].push(fractionStakeCounter);
        fractionStakeCounter++;
    }

    function unStakeToken(uint256 _id) external {
        require(tokenStakers[_id].user == msg.sender, "Not Staker");
        require(tokenStakers[_id].exists == true, "Not Staked");
        require(
            tokenStakers[_id].endsIn >= block.timestamp,
            "Token Staking not completed"
        );
        tokenStakers[_id].exists = false;
        IERC20(tokenStakers[_id].token).transferFrom(address(this), msg.sender, tokenStakers[_id].amount);
    }

    function unStakeNft(uint256 _id) external {
        require(nftStakers[_id].user == msg.sender, "Not Staker");
        require(nftStakers[_id].exists == true, "Not Staked");

        require(
            nftStakers[_id].endsIn >= block.timestamp,
            "NFT Staking not completed"
        );
        nftStakers[_id].exists = false;
        IERC721(nftStakers[_id].collection).safeTransferFrom(
            address(this),
            msg.sender,
            nftStakers[_id].tokenId
        );
    }

    function unStakeFration(uint256 _id) external {
        require(fractionStakers[_id].user == msg.sender, "Not Staker");
        require(fractionStakers[_id].exists == true, "Not Staked");

        require(
            fractionStakers[_id].endsIn >= block.timestamp,
            "NFT Staking not completed"
        );
        fractionStakers[_id].exists = false;
        IERC1155(fractionStakers[_id].collection).safeTransferFrom(
            address(this),
            msg.sender,
            fractionStakers[_id].tokenId,
            fractionStakers[_id].quantity,
            "0x00"
        );
    }

    function isTokenStakerExists(uint256 a) public view returns (bool) {
        return tokenStakers[a].exists;
    }

    function isNftStakeExists(uint256 a) public view returns (bool) {
        return nftStakers[a].exists;
    }

    function isFractionStakeExists(uint256 a) public view returns (bool) {
        return fractionStakers[a].exists;
    }

    function remainingTokenStakeTime(uint256 _id) public view returns (uint256) {
        return tokenStakers[_id].endsIn - block.timestamp;
    }

    function remainingNftStakeTime(uint256 _id) public view returns (uint256) {
        return nftStakers[_id].endsIn - block.timestamp;
    }

    function remainingFractionStakeTime(uint256 _id)
        public
        view
        returns (uint256)
    {
        return fractionStakers[_id].endsIn - block.timestamp;
    }

}

