// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStaking is IERC20 {
    
    /* ================= FUNCTIONS ================= */

    function createProvider(string memory description, uint8 commission) external;

    function editProvider(string memory description, uint8 commission) external;

    function delegate(address provider, uint256 amount) external;

    function undelegate(address provider, uint256 amount) external;

    function stake(uint256 amount) external;

    function unstake(uint256 amount) external;

    function getTotalReward() external view returns(uint256);

    function calculateProviderReward(address provider) external view returns(uint256);

    function calculateDelegatorReward(address delegator, address provider) external view returns(uint256);

    function withdrawProviderReward() external;

    function withdrawDelegatorReward(address provider) external;

    function setLockPeriod(uint256 newLockPeriod) external;

    function setMaxProviders(uint8 newMaxProviders) external;

    function setBasis(IERC20 newBasis) external;

    function setSbasis(IERC20 newSbasis) external;

    function getProvider(address provider) external view returns(address providerAddress);
}