// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStaking} from "../staking/IStaking.sol";

contract Oracle {
    IStaking public staking;

    mapping(address => uint224) public priceVotes;
    mapping(address => bytes32) public pricePreVotes;
    
    mapping(address => bool) public isValidPrice;

    uint256 public epochDuration = 30;
    uint256 public startTime;

    enum EpochTypes {
        PreVote,
        Vote
    }

    event EpochChanged(uint256 indexed epochId, EpochTypes epochType);
    event PreVoteSubmitted(address indexed provider, bytes32 hash);
    event VoteRevealed(address indexed provider, uint224 price, bool isValid);

    constructor(address stakingAddr, uint256 startTime_) {
        staking = IStaking(stakingAddr);
        startTime = startTime_;
    }

    modifier onlyProvider() {
        require(staking.getProvider(msg.sender) != address(0), "provider not registered");
        _;
    }

    function getCurrentEpochType() public view returns (EpochTypes) {
        uint256 timePassed = block.timestamp - startTime;
        uint256 epochIndex = timePassed / epochDuration;
        
        if (epochIndex % 2 == 0) {
            return EpochTypes.PreVote;
        } else {
            return EpochTypes.Vote;
        }
    }

    modifier onlyEpoch(EpochTypes requiredType) {
        require(getCurrentEpochType() == requiredType, "wrong epoch type");
        _;
    }

    // Commit Aşaması
    function pricePreVote(bytes32 hash) public onlyProvider onlyEpoch(EpochTypes.PreVote) {
        pricePreVotes[msg.sender] = hash;
        isValidPrice[msg.sender] = false; 
        
        emit PreVoteSubmitted(msg.sender, hash);
    }

    function priceVote(uint224 basisUsdPrice, bytes32 salt) public onlyProvider onlyEpoch(EpochTypes.Vote) {
        bytes32 hashedPrice = keccak256(abi.encodePacked(basisUsdPrice, salt));        
        bool isMatch = (hashedPrice == pricePreVotes[msg.sender]);
        
        if (isMatch) {
            isValidPrice[msg.sender] = true;
            priceVotes[msg.sender] = basisUsdPrice;
        } else {
            isValidPrice[msg.sender] = false;
            delete priceVotes[msg.sender]; 
        }

        emit VoteRevealed(msg.sender, basisUsdPrice, isMatch);
    }

    function getCurrentEpochInfo() public view returns(EpochTypes currentType, uint256 timeRemaining, uint256 currentTime, uint256 currentEpochId) {
        currentTime = block.timestamp;
        uint256 timePassed = currentTime - startTime;
        uint256 epochIndex = timePassed / epochDuration;
        
        currentType = (epochIndex % 2 == 0) ? EpochTypes.PreVote : EpochTypes.Vote;
        
        uint256 nextEpochStart = startTime + ((epochIndex + 1) * epochDuration);
        timeRemaining = nextEpochStart - currentTime;
        currentEpochId = epochIndex;
    }
}