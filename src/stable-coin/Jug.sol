// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {ICDPEngine} from "../interfaces/ICDPEngine.sol";
import {Auth} from "../lib/Auth.sol";
import "../lib/Math.sol";

contract Jug is Auth {
    // Ilks
    struct Collateral {
        // duty
        uint256 fee; // Collateral-specific, per-second stability fee contribution [ray]
        // rho
        uint256 updated_at; // Time of last drip [unix epoch time]
    }

    // ilk
    mapping(bytes32 => Collateral) public collaterals;
    // vat
    ICDPEngine public cdp_engine; // CDP Engine
    // vow
    address public ds_engine; // Debt Engine (ds stands for `debt surplus`)
    // base
    uint256 public base_fee; // Global, per-second stability fee contribution [ray]

    // --- Init ---
    constructor(address _cdp_engine) {
        cdp_engine = ICDPEngine(_cdp_engine);
    }

    // --- Administration ---
    function init(bytes32 col_type) external auth {
        Collateral storage col = collaterals[col_type];
        require(col.fee == 0, "collateral-already-init");
        col.fee = RAY;
        col.updated_at = block.timestamp;
    }

    // file
    function set(bytes32 col_type, bytes32 key, uint256 data) external auth {
        require(block.timestamp == collaterals[col_type].updated_at, "Jug/rho-not-updated");
        if (key == "fee") collaterals[col_type].fee = data;
        else revert("unrecognized-param");
    }

    // file
    function set(bytes32 key, uint256 data) external auth {
        if (key == "base_fee") base_fee = data;
        else revert("unrecognized-param");
    }

    // file
    function set(bytes32 key, address data) external auth {
        if (key == "ds_engine") ds_engine = data;
        else revert("unrecognized-param");
    }

    // --- Stability Fee Collection ---
    //drip
    function collect_stability_fee(bytes32 col_type) external returns (uint256 rate) {
        require(block.timestamp >= collaterals[col_type].updated_at, "invalid-timestamp");
        ICDPEngine.Collateral memory col = cdp_engine.collaterals(col_type);
        rate = Math.rmul(
            Math.rpow(base_fee + collaterals[col_type].fee, block.timestamp - collaterals[col_type].updated_at, RAY),
            col.rate_acc
        );
        cdp_engine.fold(col_type, ds_engine, Math.diff(rate, col.rate_acc));
        collaterals[col_type].updated_at = block.timestamp;
    }
}
