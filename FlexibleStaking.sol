//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlexibleStaking is ReentrancyGuard, Ownable {

    uint256 public MIN_STAKE_AMOUNT = 0;
    bool public CONTRACT_RENOUNCED = false;

    string private constant NEVER_CONTRIBUTED_ERROR = "This address has never contributed to the protocol";
    string private constant NO_ETH_CONTRIBUTIONS_ERROR = "No Contributions";
    string private constant MINIMUM_CONTRIBUTION_ERROR = "Contributions must be over the minimum contribution amount";
    

    struct Staker {
      address addr; 
      uint256 lifetime_contribution;
      uint256 contribution;
      uint256 yield;
      uint256 unstakeable;
      uint256 joined;
      bool exists;
    }

    mapping(address => Staker) public stakers;
    address[] public stakerList;

    constructor(uint256 _min_stake_amount) ReentrancyGuard() payable {
      MIN_STAKE_AMOUNT = _min_stake_amount;
    }

    receive() external payable {}
    fallback() external payable {}

    function AddStakerYield(address addr, uint256 a) private {
      stakers[addr].yield = stakers[addr].yield + a;
    }

    function RemoveStakerYield(address addr, uint256 a) private {
      stakers[addr].yield = stakers[addr].yield - a;
    }

    function RenounceContract() external onlyOwner {
      CONTRACT_RENOUNCED = true;
    }

    function ChangeMinimumStakingAmount(uint256 a) external onlyOwner {
        MIN_STAKE_AMOUNT = a;
    }

    function UnstakeAll() external onlyOwner {
        if(CONTRACT_RENOUNCED == true){revert("Contract Renounced");}
        for (uint i = 0; i < stakerList.length; i++) {
            address user = stakerList[i];
            if(stakers[user].unstakeable>0){   
            RemoveStake(user);
            }
        }
    }

    function Stake() external nonReentrant payable {
      require(msg.value >= MIN_STAKE_AMOUNT, MINIMUM_CONTRIBUTION_ERROR);
      uint256 unstakeable = msg.value;

      if(StakerExists(msg.sender)){
        stakers[msg.sender].lifetime_contribution = stakers[msg.sender].lifetime_contribution + unstakeable;
        stakers[msg.sender].contribution = stakers[msg.sender].contribution + unstakeable;
        stakers[msg.sender].unstakeable = stakers[msg.sender].unstakeable + unstakeable;
      }else{
        Staker memory user;
        user.addr = msg.sender;
        user.contribution = unstakeable;
        user.lifetime_contribution = unstakeable;
        user.yield = 0;
        user.exists = true;
        user.unstakeable = unstakeable;
        user.joined = block.timestamp;
        stakers[msg.sender] = user;
        stakerList.push(msg.sender);
      }
    }

    function Unstake() external {
      address user = msg.sender;
      if(!StakerExists(user)){ revert(NEVER_CONTRIBUTED_ERROR); }
      uint256 uns = stakers[user].unstakeable;
      require(uns>0, "Zero balance");
      uint256 yieldTotal = calculateYieldTotal(user);
      uint256 totalReward = uns + yieldTotal;
      stakers[user].unstakeable = 0;
      stakers[user].contribution = 0;
      stakers[user].joined = 0;
      payable(user).transfer(totalReward);
    }

    function RemoveStake(address user) private {
      if(!StakerExists(user)){ revert(NEVER_CONTRIBUTED_ERROR); }
      uint256 uns = stakers[user].unstakeable;
      require(uns>0, "Zero balance");
       uint256 yieldTotal = calculateYieldTotal(user);
      uint256 totalReward = uns + yieldTotal;
      stakers[user].unstakeable = 0;
      stakers[user].contribution = 0;
      stakers[user].joined = 0;
      payable(user).transfer(totalReward);

    }
    
    function calculateYieldTime(address user) public view returns(uint256){
        uint256 end = block.timestamp;
        uint256 totalTime = end - stakers[user].joined;
        return totalTime;
    }

    function calculateYieldTotal(address user) public view returns(uint256) {
        uint256 time = calculateYieldTime(user);
        uint256 rawYield = stakers[user].unstakeable * time / 3.154e7; 
        return rawYield;
    }

    function StakerExists(address a) public view returns(bool){
      return stakers[a].exists;
    }

    function StakerCount() public view returns(uint256){
      return stakerList.length;
    }

    function GetStakeJoinDate(address a) public view returns(uint256){
      if(!StakerExists(a)){revert(NEVER_CONTRIBUTED_ERROR);}
      return stakers[a].joined;
    }

    function GetStakerYield(address a) public view returns(uint256){
      if(!StakerExists(a)){revert(NEVER_CONTRIBUTED_ERROR);}
      return stakers[a].yield;
    }
  
    function GetStakingAmount(address a) public view returns (uint256){
      if(!StakerExists(a)){revert(NEVER_CONTRIBUTED_ERROR);}
      return stakers[a].contribution;
    }

    function GetStakerPercentageByAddress(address a) public view returns(uint256){
      if(!StakerExists(a)){revert(NEVER_CONTRIBUTED_ERROR);}
      uint256 c_total = 0;
      for (uint i = 0; i < stakerList.length; i++) {
         c_total = c_total + stakers[stakerList[i]].contribution;
      }
      if(c_total == 0){revert(NO_ETH_CONTRIBUTIONS_ERROR);}
      return (stakers[a].contribution * 10000) / c_total;
    }

    function GetStakerUnstakeableAmount(address addr) public view returns(uint256) {
      if(StakerExists(addr)){ return stakers[addr].unstakeable; }else{ return 0; }
    }

    function GetLifetimeContributionAmount(address a) public view returns (uint256){
      if(!StakerExists(a)){revert("This address has never contributed DAI to the protocol");}
      return stakers[a].lifetime_contribution;
    }

    function CheckContractRenounced() external view returns(bool){
      return CONTRACT_RENOUNCED;
    }



}
