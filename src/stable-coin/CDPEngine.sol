// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.24;

import {Auth} from "../lib/Auth.sol";
import {CircuitBreaker} from "../lib/CircuitBreaker.sol";
import {Math} from "../lib/Math.sol";

// Vat
// CDP stands for Collateralized Debt Positon
contract CDPEngine is Auth, CircuitBreaker {
    // Ilk
    struct Collateral {
        // Art - total Normalised Debt [wad]
        // di = delta debt at time i
        // ri = rate_acc at time i
        // Art = d0 / r0 + d1 / r1 + d2 / r2 ...
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

    // Urn - vault (CDP)
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

    // global debt
    uint256 public sys_debt;

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

    /// @notice Modify the CDP
    // frob(i, u, v, w, dink, dart)
    // - modify position of user u
    // - using gem from user v
    // - and creating coin for user w
    // dink: change in amount of collateral
    // dart: change in amount of debt
    function modify_cdp(
        // i - collateral id
        bytes32 col_type,
        // u - address that maps to CDP
        address cdp,
        // v - source of gem
        address gem_src,
        // w - destination of coin
        address coin_dst,
        // dink - delta collateral
        int256 delta_col,
        // dart - delta debt
        int256 delta_debt
    ) external not_stopped {
        Position memory pos = positions[col_type][cdp];
        Collateral memory col = collaterals[col_type];
        // collateral(ilk) has been initialised
        require(col.rate_acc != 0, "collateral not initialized");

        pos.collateral = Math.add(pos.collateral, delta_col);
        pos.debt = Math.add(pos.debt, delta_col);
        col.debt = Math.add(col.debt, delta_debt);

        // coin [rad] = col.rate_acc * debt
        int256 delta_coin = Math.mul(col.rate_acc, delta_debt); // dtab
        uint256 coin_debt = col.rate_acc * pos.debt; // tab
        sys_debt = Math.add(sys_debt, delta_coin);

        // either debt has decreased, or debt ceilings are not exceeded
        require(
            delta_debt <= 0 || (col.debt * col.rate_acc <= col.max_debt && sys_debt <= sys_max_debt),
            "Vat/ceiling-exceeded"
        );
        // postion(urn) is either less risky than before, or it is safe
        require((delta_debt <= 0 && delta_col >= 0) || coin_debt <= pos.collateral * col.spot, "Vat/not-safe");
        // position(urn) is either more safe, or the owner consents
        require((delta_debt <= 0 && delta_col >= 0) || can_modify_account(cdp, msg.sender), "Vat/not-allowed-u");
        // collateral src consents
        require(delta_col <= 0 || can_modify_account(gem_src, msg.sender), "Vat/not-allowed-v");
        // debt dst consents
        require(delta_debt >= 0 || can_modify_account(coin_dst, msg.sender), "Vat/not-allowed-w");
        // position(urn) has no debt, or a non-dusty amount
        require(pos.debt == 0 || coin_debt >= col.min_debt, "Vat/dust");

        // Moving col from local gem to pos, hence oppiste sign
        // local collateral -> - gem, + pos (delta_debt >= 0)
        // free collateral -> + gem, - pos (delta_debt <= 0)
        gem[col_type][gem_src] = Math.sub(gem[col_type][gem_src], delta_col);
        coin[coin_dst] = Math.add(coin[coin_dst], delta_coin);

        positions[col_type][cdp] = pos;
        collaterals[col_type] = col;
    }

    function fold(bytes32 col_type, address coin_dst, int256 delta_rate) external auth not_stopped {
        Collateral storage col = collaterals[col_type];
        col.rate_acc = Math.add(col.rate_acc, delta_rate);
        // old total debt = col.rate_acc * col.debt
        // new total debt = (col.rate_acc + delta_rate) * col.debt
        // delta_coin = new total debt - old total debt
        //            = (col.rate_acc + delta_rate) * col.debt
        //             - col.rate_acc * col.debt
        //            = col.debt * delta_rate
        int256 delta_coin = Math.mul(col.debt, delta_rate);
        coin[coin_dst] = Math.add(coin[coin_dst], delta_coin);
        sys_debt = Math.add(sys_debt, delta_coin);
    }
}
