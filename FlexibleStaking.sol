//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./BetToken.sol";

contract FlexibleStaking is ReentrancyGuard, Ownable {
    uint256 public MIN_STAKE_AMOUNT = 0;
    bool private CONTRACT_RENOUNCED = false;

    string private constant ZERO_BAL = "Zero Balance";
    string private constant NO_CONTRIBUTION = "No Contributions";
    string private constant NEVER_CONTRIBUTED = "Address has never contributed";
    string private constant MIN_CONTRIBUTION =
        "Amount less than minimum contribution amount";

    struct Staker {
        address addr;
        uint256 previous_contribution;
        uint256 contribution;
        uint256 joined;
        bool exists;
    }

    mapping(address => Staker) public stakers;
    address[] public stakerList;
    address[] private auxArray;
    BetToken betToken;

    constructor(uint256 _min_stake_amount, BetToken _pmknToken)
        payable
        ReentrancyGuard()
    {
        betToken = _pmknToken;
        MIN_STAKE_AMOUNT = _min_stake_amount;
    }

    receive() external payable {}

    fallback() external payable {}

    function RenounceContract() external onlyOwner {
        CONTRACT_RENOUNCED = true;
    }

    function ChangeMinimumStakingAmount(uint256 a) external onlyOwner {
        MIN_STAKE_AMOUNT = a;
    }

    function UnstakeAll() external onlyOwner {
        if (CONTRACT_RENOUNCED == true) {
            revert("Contract Renounced");
        }
        for (uint256 i = 0; i < stakerList.length; i++) {
            address user = stakerList[i];
            if (stakers[user].contribution > 0) {
                RemoveStake(user);
            }
        }
        delete stakerList;
    }

    function Stake(uint256 amount) external payable nonReentrant {
        require(msg.value >= MIN_STAKE_AMOUNT, MIN_CONTRIBUTION);
        address user = msg.sender;
        betToken.transferFrom(msg.sender, address(this), amount);

        if (isStakerExists(user)) {
            uint256 yieldTotal = calculateYieldTotal(user);
            uint256 totalReward = stakers[msg.sender].contribution + yieldTotal;
            stakers[msg.sender].previous_contribution = totalReward;
            stakers[user].joined = block.timestamp;
            stakers[msg.sender].contribution = totalReward + amount;
        } else {
            Staker memory newUser;
            newUser.addr = user;
            newUser.contribution = amount;
            newUser.previous_contribution = amount;
            newUser.exists = true;
            newUser.joined = block.timestamp;
            stakers[user] = newUser;
            stakerList.push(user);
        }
    }

    function Unstake() external {
        address user = msg.sender;
        if (!isStakerExists(user)) {
            revert(NEVER_CONTRIBUTED);
        }
        uint256 uns = stakers[user].contribution +
            stakers[user].previous_contribution;
        require(uns > 0, "Zero balance");
        uint256 yieldTotal = calculateYieldTotal(user);
        uint256 totalReward = uns + yieldTotal;
        stakers[user].contribution = 0;
        stakers[user].joined = 0;
        stakerList = remove(user, stakerList);
        delete auxArray;
        betToken.transfer(user, totalReward);
    }

    function RemoveStake(address user) private {
        if (!isStakerExists(user)) {
            revert(NEVER_CONTRIBUTED);
        }
        uint256 uns = stakers[user].contribution +
            stakers[user].previous_contribution;
        require(uns > 0, "Zero balance");
        uint256 yieldTotal = calculateYieldTotal(user);
        uint256 totalReward = uns + yieldTotal;
        stakers[user].contribution = 0;
        stakers[user].joined = 0;
        stakerList = remove(user, stakerList);
        delete auxArray;
        betToken.transfer(user, totalReward);
    }

    function calculateYieldTime(address user) public view returns (uint256) {
        uint256 end = block.timestamp;
        uint256 totalTime = end - stakers[user].joined;
        return totalTime;
    }

    function calculateYieldTotal(address user) public view returns (uint256) {
        uint256 time = calculateYieldTime(user);
        uint256 rawYield = (stakers[user].contribution * time) / 3.154e7;
        return rawYield;
    }

    function remove(address user, address[] storage _array)
        private
        returns (address[] memory)
    {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] != user) auxArray.push(_array[i]);
        }

        return auxArray;
    }

    function isStakerExists(address a) public view returns (bool) {
        return stakers[a].exists;
    }

    function StakerCount() public view returns (uint256) {
        return stakerList.length;
    }

    function GetStakingAmount(address a) public view returns (uint256) {
        if (!isStakerExists(a)) {
            revert(NEVER_CONTRIBUTED);
        }
        return stakers[a].contribution;
    }

    function GetStakerPercentageByAddress(address a)
        public
        view
        returns (uint256)
    {
        if (!isStakerExists(a)) {
            revert(NEVER_CONTRIBUTED);
        }
        uint256 c_total = 0;
        for (uint256 i = 0; i < stakerList.length; i++) {
            c_total = c_total + stakers[stakerList[i]].contribution;
        }
        if (c_total == 0) {
            revert(NO_CONTRIBUTION);
        }
        return (stakers[a].contribution * 10000) / c_total;
    }

    function GetLifetimeContributionAmount(address a)
        public
        view
        returns (uint256)
    {
        if (!isStakerExists(a)) {
            revert("This address has never contributed DAI to the protocol");
        }
        return stakers[a].previous_contribution;
    }

    function CheckContractRenounced() external view returns (bool) {
        return CONTRACT_RENOUNCED;
    }
}
