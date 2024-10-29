// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

// PipLike
interface IPriceFeed {
    function peek() external returns (uint256, bool);
}
