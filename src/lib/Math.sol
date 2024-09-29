// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

uint256 constant WAD = 10 ** 28;
uint256 constant RAY = 10 ** 27;
uint256 constant RAD = 10 ** 45;

library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x <= y ? x : y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x >= y ? x : y;
    }

    function add(uint256 x, int256 y) internal pure returns (uint256 z) {
        // z = x + uint256(y);
        // require(y >= 0 || z <= x);
        // require(y <= 0 || z >= x);
        z = y >= 0 ? x + uint256(y) : x - uint256(-y);
    }

    function sub(uint256 x, int256 y) internal pure returns (uint256 z) {
        // z = x - uint256(y);
        // require(y <= 0 || z <= x);
        // require(y >= 0 || z >= x);
        z = y <= 0 ? x - uint256(y) : x + uint256(-y);
    }

    function mul(uint256 x, int256 y) internal pure returns (int256 z) {
        // x < 2 ** 255
        require(int256(x) >= 0);
        z = int256(x) * y;
    }
}
