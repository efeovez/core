// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStaking} from "../staking/IStaking.sol";

contract Oracle {

    IStaking public staking;

    mapping(address => uint224) public priceVotes;

    mapping(address => bytes32) public pricePreVotes;

    mapping(address => bool) public isValidPrice;

    constructor(address stakingAddr) {
        staking = IStaking(stakingAddr);
    }

    modifier onlyProvider() {
        require(staking.getProvider(msg.sender) != address(0), "basis.getProvider: provider not registered");
        _;
    }

    function priceVote(uint224 basisUsdPrice) public onlyProvider returns(bytes32) {
        require(block.number % 5 == 0, "basis.priceVote: can only vote every 5 blocks");

        bytes32 hashedPrice = keccak256(abi.encodePacked(basisUsdPrice));

        if (hashedPrice == getPricePreVote(msg.sender)) {
            isValidPrice[msg.sender] = true;
        } else {
            isValidPrice[msg.sender] = false;
        }
        
        priceVotes[msg.sender] = basisUsdPrice;

        return hashedPrice;
    }

    function pricePreVote(bytes32 BasisUsdPrice) public onlyProvider {
        require(block.number % 5 == 0, "basis.priceVote: can only vote every 5 blocks");

        pricePreVotes[msg.sender] = BasisUsdPrice;
    }

    function getPriceVote(address provider) public view returns(uint224) {
        return priceVotes[provider];
    }

    function getPricePreVote(address provider) public view returns(bytes32) {
        return pricePreVotes[provider];
    }
}