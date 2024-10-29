// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {ICDPEngine} from "../interfaces/ICDPEngine.sol";
import {Auth} from "../lib/Auth.sol";
import {CircuitBreaker} from "../lib/CircuitBreaker.sol";
import "../lib/Math.sol";

contract Pot is Auth, CircuitBreaker {
    // --- Data ---
    mapping(address => uint256) public pie; // Normalised Savings Dai [wad]

    // Pie
    uint256 public total_pie; // Total Normalised Savings Dai  [wad]
    // dsr
    uint256 public savings_rate; // The Dai Savings Rate          [ray]
    // chi
    uint256 public rate_acc; // The Rate Accumulator          [ray]

    // vat
    ICDPEngine public cdp_engine; // CDP Engine
    // vow
    address public ds_engine; // Debt Engine
    // rho
    uint256 public updated_at; // Time of last drip     [unix epoch time]

    // --- Init ---
    constructor(address _cdp_engine) {
        cdp_engine = ICDPEngine(_cdp_engine);
        savings_rate = RAY;
        rate_acc = RAY;
        updated_at = block.timestamp;
    }

    // --- Administration ---
    // file
    function set(bytes32 key, uint256 data) external auth not_stopped {
        require(block.timestamp == updated_at, "time-not-updated");
        if (key == "savings_rate") savings_rate = data;
        else revert("unrecognized-param");
    }

    // file
    function set(bytes32 key, address addr) external auth {
        if (key == "ds_engine") ds_engine = addr;
        else revert("unrecognized-param");
    }

    // cage
    function stop() external auth {
        _stop();
        savings_rate = RAY;
    }

    // --- Savings Rate Accumulation ---
    // drip
    function collect_stability_fee() external returns (uint256) {
        require(block.timestamp >= updated_at, "invalid-timestamp");
        uint256 acc = Math.rmul(Math.rpow(savings_rate, block.timestamp - updated_at, RAY), rate_acc);
        uint256 delta_rate_acc = acc - rate_acc;
        rate_acc = acc;
        updated_at = block.timestamp;
        // old total DAI = total_pie * old rate_acc
        // new total DAI = total_pie * new rate_acc
        // amount of DAI to mint = total_pai * (new rate_acc - ole rate_acc)
        cdp_engine.mint(address(ds_engine), address(this), total_pie * delta_rate_acc);
        return acc;
    }

    // --- Savings Dai Management ---
    function join(uint256 wad) external {
        require(block.timestamp == updated_at, "time-not-updated");
        pie[msg.sender] += wad;
        total_pie += wad;
        cdp_engine.transfer_coin(msg.sender, address(this), rate_acc * wad);
    }

    function exit(uint256 wad) external {
        pie[msg.sender] -= wad;
        total_pie -= wad;
        cdp_engine.transfer_coin(address(this), msg.sender, rate_acc * wad);
    }
}
