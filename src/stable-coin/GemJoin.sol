// SPDX-License-Identifier: AGPL-3.0-or-later
// This contract is part of the `join.sol` of dss

pragma solidity ^0.8.24;

import {Auth} from "../lib/Auth.sol";
import {CircuitBreaker} from "../lib/CircuitBreaker.sol";

// GemLike
interface IGem {
    function decimals() external view returns (uint8);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

// VatLike
interface ICDPEngine {
    // move
    function modify_collateral_balance(bytes32, address, int256) external;
}

// GemJoin - for well behaved ERC20 token, with simple transfer semantics
contract GemJoin is Auth, CircuitBreaker {
    ICDPEngine public cdp_engine; // CDP Engine
    bytes32 public collateral_type; // Collateral Type
    IGem public gem;
    uint8 public decimals;

    // Events
    event Join(address indexed usr, uint256 wad);
    event Exit(address indexed usr, uint256 wad);

    constructor(address _cdp_engine, bytes32 _collateral_type, address _gem) {
        cdp_engine = ICDPEngine(_cdp_engine);
        collateral_type = _collateral_type;
        gem = IGem(_gem);
        decimals = gem.decimals();
    }

    function stop() external auth {
        _stop();
    }

    // Enter collateral to the system
    function join(address usr, uint256 wad) external not_stopped {
        require(int256(wad) >= 0, "overflow");
        cdp_engine.modify_collateral_balance(collateral_type, usr, int256(wad));
        require(gem.transferFrom(msg.sender, address(this), wad), "transfer failed");
        emit Join(usr, wad);
    }

    // Remove collateral to the system
    function exit(address usr, uint256 wad) external {
        require(wad <= 2 ** 255, "overflow");
        cdp_engine.modify_collateral_balance(collateral_type, msg.sender, -int256(wad));
        require(gem.transfer(usr, wad), "transfer failed");
        emit Exit(usr, wad);
    }
}
