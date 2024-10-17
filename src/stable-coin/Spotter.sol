// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Auth} from "../lib/Auth.sol";
import {Math} from "../lib/Math.sol";
import {CircuitBreaker} from "../lib/CircuitBreaker.sol";

// VatLike
interface ICDPEngine {
    // file
    function set(bytes32, bytes32, uint256) external;
}

// PipLike
interface IPriceFeed {
    function peek() external returns (uint256, bool); // [wad]
}

// Spot
contract Spotter is Auth, CircuitBreaker {
    // Ilk
    struct Collateral {
        IPriceFeed pip; // Price Feed
        // mat
        // spot = val(from price feed) / mat
        uint256 liquidation_ratio; // Liquidation ratio [ray]
    }

    // Ilks
    mapping(bytes32 => Collateral) public collaterals;

    // vat
    ICDPEngine public cdp_engine; // CDP Engine

    // par [ray] - value of DAI in the reference asset (e.g. $1 per BEI)
    // represent as dollar
    uint256 public par; // ref per dai [ray]

    // --- Events ---
    event Poke(bytes32 col_type, uint256 val, uint256 spot);

    // --- Init ---
    constructor(address _cdp_engine) {
        cdp_engine = ICDPEngine(_cdp_engine);
        // represent 1 dollar [ray]
        par = 1 * 10 ** 27;
    }

    // --- Administration ---
    // file
    function set(bytes32 col_type, bytes32 key, address pip_) external auth not_stopped {
        if (key == "pip") collaterals[col_type].pip = IPriceFeed(pip_);
        else revert("Spotter/file-unrecognized-param");
    }

    // file
    function set(bytes32 key, uint256 data) external auth not_stopped {
        if (key == "par") par = data;
        else revert("Spotter/file-unrecognized-param");
    }

    // file
    function set(bytes32 col_type, bytes32 key, uint256 data) external auth not_stopped {
        if (key == "liquidation_ratio") collaterals[col_type].liquidation_ratio = data;
        else revert("Spotter/file-unrecognized-param");
    }

    // --- Update value ---
    function poke(bytes32 col_type) external {
        (uint256 val, bool ok) = collaterals[col_type].pip.peek();
        //         wad * 10 ** 9 / ray  / liquidation_ratio
        // spot = (val * 10 ** 8 / par) / liquidation_ratio
        uint256 spot = ok ? Math.rdiv(Math.rdiv(val * 10 ** 9, par), collaterals[col_type].liquidation_ratio) : 0;
        cdp_engine.set(col_type, "spot", spot);
        emit Poke(col_type, val, spot);
    }

    // cage
    function stop() external auth {
        _stop();
    }
}
