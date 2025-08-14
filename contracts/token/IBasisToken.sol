// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../libs/IERC20.sol";

interface IBasisToken is IERC20 {

    /* ================= FUNCTIONS ================= */

    function mint(address account, uint256 amount) external returns (bool);

    function burn(uint256 amount) external;

    function burnFrom(address from, uint256 amount) external;

    function isGovernor() external view returns (bool);

    function getGovernor() external view returns (address);
}