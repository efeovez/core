// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBasisToken is IERC20 {

    /* ================= FUNCTIONS ================= */

    function mint(address account, uint256 amount) external returns (bool);

    function burn(uint256 amount) external;

    function burnFrom(address from, uint256 amount) external;

    function isOperator() external view returns (bool);

    function getOperator() external view returns (address);
}