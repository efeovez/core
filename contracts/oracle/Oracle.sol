// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStaking} from "../staking/IStaking.sol";

contract Oracle {

    IStaking public staking;

    mapping(address => uint224) public priceVotes;

    mapping(address => bytes32) public pricePreVotes;

    mapping(address => bool) public isValidPrice;

    uint256 public startTime = block.timestamp;

    uint256 public epochStart = block.timestamp;

    uint256 public targetEpoch = epochStart + 30;

    enum EpochTypes {
        PreVote,
        Vote
    }

    event EpochChanged(EpochTypes newEpochType, uint256 timestamp);

    EpochTypes public epochType = EpochTypes.PreVote;

    constructor(address stakingAddr) {
        staking = IStaking(stakingAddr);
    }

    modifier onlyProvider() {
        require(staking.getProvider(msg.sender) != address(0), "basis.getProvider: provider not registered");
        _;
    }

    function updateEpoch() public {
        if (block.timestamp >= targetEpoch) {
            if (epochType == EpochTypes.PreVote) {
                epochType = EpochTypes.Vote;
            } else {
                epochType = EpochTypes.PreVote;
            }
            epochStart = block.timestamp;
            targetEpoch = block.timestamp + 30;
            
            emit EpochChanged(epochType, block.timestamp);
        }
    }

    modifier autoUpdateEpoch() {
        updateEpoch();
        _;
    }

    function priceVote(uint224 basisUsdPrice) public onlyProvider autoUpdateEpoch returns(bytes32) {
        require(epochType == EpochTypes.Vote, "basis.priceVote: can only vote epochType is Vote");

        if (block.timestamp >= targetEpoch) {
            epochStart = block.timestamp;
            targetEpoch = block.timestamp + 30;
            epochType = EpochTypes.PreVote;
        }

        bytes32 hashedPrice = keccak256(abi.encodePacked(basisUsdPrice));

        if (hashedPrice == getPricePreVote(msg.sender)) {
            isValidPrice[msg.sender] = true;
        } else {
            isValidPrice[msg.sender] = false;
        }
        
        priceVotes[msg.sender] = basisUsdPrice;

        return hashedPrice;
    }

    function pricePreVote(bytes32 BasisUsdPrice) public onlyProvider autoUpdateEpoch {
        require(epochType == EpochTypes.PreVote, "basis.priceVote: can only vote epochType is PreVote");

        if (block.timestamp >= targetEpoch) {
            epochStart = block.timestamp;
            targetEpoch = block.timestamp + 30;
            epochType = EpochTypes.Vote;
        }

        pricePreVotes[msg.sender] = BasisUsdPrice;
    }

    function getPriceVote(address provider) public view returns(uint224) {
        return priceVotes[provider];
    }

    function getPricePreVote(address provider) public view returns(bytes32) {
        return pricePreVotes[provider];
    }

    function getCurrentEpochInfo() public view returns(
        EpochTypes currentType,
        uint256 timeRemaining,
        uint256 currentTime) {
        currentType = epochType;
        currentTime = block.timestamp;
        timeRemaining = targetEpoch > block.timestamp ? targetEpoch - block.timestamp : 0;
    }
}