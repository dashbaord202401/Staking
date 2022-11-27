// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";


contract LockedStaking is ReentrancyGuard, Ownable, ERC721HolderUpgradeable {
    uint256 public MIN_STAKE_AMOUNT = 0;
    uint256 public STAKE_PERIOD = 63158400;

    string private constant ZERO_BAL = "Zero Balance";
    string private constant NO_CONTRIBUTION = "No Contributions";
    string private constant NEVER_CONTRIBUTED = "Address has never contributed";
    string private constant MIN_CONTRIBUTION = "Amount less than minimum contribution amount";

    struct tokenStaker {
        address user;
        address token;
        uint256 contribution;
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

    mapping(address => tokenStaker) public tokenStakers;
    mapping(address => nftStaker) public nftStakers;
    address[] public tokenStakerList;
    address[] public nftStakerList;
    address[] private auxArray;

    constructor(uint256 _amount)
        ReentrancyGuard()
    {
        MIN_STAKE_AMOUNT = _amount;
    }

    receive() external payable {}

    fallback() external payable {}


    function tokenStake(address token, uint256 amount) external nonReentrant {
        require(tokenStakers[msg.sender].exists == false, "Already Staked");
        require(amount >= MIN_STAKE_AMOUNT, MIN_CONTRIBUTION);
        address user = msg.sender;
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        tokenStaker memory newUser;
        newUser.user = user;
        newUser.token = token;
        newUser.contribution = amount;
        newUser.exists = true;
        newUser.joined = block.timestamp;
        newUser.endsIn = block.timestamp + STAKE_PERIOD;
        tokenStakers[user] = newUser;
        tokenStakerList.push(user);
    }
    
    function nftStake(address _collection, uint256 _tokenId) external {
        require(nftStakers[msg.sender].exists == false, "Already Staked");
        IERC721(_collection).safeTransferFrom(msg.sender, address(this), _tokenId);
        address user = msg.sender;
        nftStaker memory newUser;
        newUser.user = user;
        newUser.collection = _collection;
        newUser.tokenId = _tokenId;
        newUser.exists = true;
        newUser.joined = block.timestamp;
        newUser.endsIn = block.timestamp + STAKE_PERIOD;
        nftStakers[user] = newUser;
        nftStakerList.push(user);
    }

    function unStakeToken (address _token) external{
        require(tokenStakers[msg.sender].exists == true, "Not Staked");
        require(tokenStakers[msg.sender].endsIn >= block.timestamp, "Token Staking not completed");
        uint256 stakedAmount = tokenStakers[msg.sender].contribution;
        tokenStakers[msg.sender].exists = false;
        IERC20(_token).transferFrom(address(this), msg.sender, stakedAmount);
    }

    function unStakeNft (address _collection, uint256 _tokenId)external{
        require(nftStakers[msg.sender].exists == true, "Not Staked");
        require(nftStakers[msg.sender].endsIn >= block.timestamp, "NFT Staking not completed");
        nftStakers[msg.sender].exists = false;
        IERC721(_collection).safeTransferFrom( address(this), msg.sender, _tokenId);


    }

    function isTokenStakerExists(address a) public view returns (bool) {
        return tokenStakers[a].exists;
    }

    function isNftStakerExists(address a) public view returns (bool) {
        return nftStakers[a].exists;
    }

    function remainingTokenStakeTime() public view returns (uint256) {
        return tokenStakers[msg.sender].endsIn - block.timestamp;
    }

    function remainingNftStakeTime() public view returns (uint256) {
        return nftStakers[msg.sender].endsIn - block.timestamp;
    }

    function toekenStakerCount() public view returns (uint256) {
        return tokenStakerList.length;
    }

    function nftStakerCount() public view returns (uint256) {
        return nftStakerList.length;
    }

}
