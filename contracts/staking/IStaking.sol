// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStaking is IERC20 {
    
    /* ================= FUNCTIONS ================= */

    function createProvider(string calldata description, uint8 commission) external;

    function editProvider(string calldata description, uint8 commission) external;

    function delegate(address provider, uint256 amount) external;

    function undelegate(address provider) external;

    function lastTimeRewardApplicable(address provider) external view returns (uint256);

    function rewardPerLpBasis(address provider) external view returns (uint256);

    function earned(address delegator, address provider) external view returns (uint256);

    function getRewardForDuration(address provider) external view returns (uint256);

    function withdrawDelegatorReward(address provider) external;

    function notifyRewardAmount(uint256 reward, address provider) external;

    function withdrawProviderCommission() external;

    function getProvider(address provider) external view returns(address providerAddress);

    function setLpBasis(IERC20 newLpBasis) external;

    function setMaxProviders(uint8 newMaxProviders) external;

    function setLockPeriod(uint256 newLockPeriod) external;

    function setCommissionUpdateLock(uint256 newCommissionUpdateLock) external;
}