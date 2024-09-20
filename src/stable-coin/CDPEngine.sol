// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.24;

import {Auth} from "../lib/Auth.sol";
import {CircuitBreaker} from "../lib/CircuitBreaker.sol";

library Math {
    function add(uint256 x, int256 y) internal pure returns (uint256 z) {
        // z = x + uint256(y);
        // require(y >= 0 || z <= x);
        // require(y <= 0 || z >= x);
        return y >= 0 ? x + uint256(y) : x - uint256(y);
    }
}

// Vat
// CDP stands for Collateralized Debt Positon
contract CDPEngine is Auth, CircuitBreaker {
    // Ilk
    struct Collateral {
        // Art - total Normalised Debt [wad]
        uint256 debt;
        // rate - Accumulated Rates [ray]
        uint256 rate_acc;
        // spot - Price with Safety Margin [ray]
        uint256 spot;
        // line - Debt Ceiling [rad]
        uint256 max_debt;
        // dust - Urn Debt Floor [rad]
        uint256 min_debt;
    }

    // Urn
    struct Position {
        // ink - Locked Collateral [wad]
        uint256 collateral;
        // art - Normalised Debt [wad]
        uint256 debt;
    }

    // ilks
    mapping(bytes32 => Collateral) public collaterals;

    // urns
    mapping(bytes32 => mapping(address => Position)) public positions;

    // collateral type => user => balance of collateral [wad]
    mapping(bytes32 => mapping(address => uint256)) public gem;

    // user => stable coin balance [rad]
    mapping(address => uint256) public coin; // dai

    // owner => user => boolean
    mapping(address => mapping(address => bool)) public can;

    // Line - Total Debt Ceiling [rad]
    uint256 public sys_max_debt;

    // init
    function init(bytes32 col_type) external view auth {
        require(collaterals[col_type].rate_acc == 0, "collateral already init");
        collaterals[col_type].rate_acc == 10 ** 27;
    }

    // file
    function set(bytes32 key, uint256 val) external auth not_stopped {
        if (key == "sys_max_debt") sys_max_debt = val;
        else revert("key not recognized");
    }

    // file
    function set(bytes32 col_type, bytes32 key, uint256 val) external auth not_stopped {
        if (key == "spot") collaterals[col_type].spot = val;
        else if (key == "max_debt") collaterals[col_type].max_debt = val;
        else if (key == "min_debt") collaterals[col_type].min_debt = val;
        else revert("key not recognized");
    }

    // cage
    function cage() external auth {
        _stop();
    }

    // hope
    function allow_account_modification(address user) external {
        can[msg.sender][user] = true;
    }

    // nope
    function deny_account_modification(address user) external {
        can[msg.sender][user] = false;
    }

    // wish
    function can_modify_account(address owner, address user) internal view returns (bool) {
        return owner == user || can[owner][user];
    }

    // move
    function transfer_coin(address src, address dst, uint256 rad) external {
        require(can_modify_account(src, msg.sender), "Vat/not-allowed");
        coin[src] -= rad;
        coin[dst] += rad;
    }

    function modify_collateral_balance(bytes32 col_type, address user, int256 wad) external auth {
        gem[col_type][user] = Math.add(gem[col_type][user], wad);
    }
}
