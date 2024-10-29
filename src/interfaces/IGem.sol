// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

// GemLike
interface IGem {
    function decimals() external view returns (uint8);
    function approve(address spender, uint256 amount) external;
    function transfer(address dst, uint256 amount) external returns (bool);
    function transferFrom(address dsc, address dst, uint256 amount) external returns (bool);
}
