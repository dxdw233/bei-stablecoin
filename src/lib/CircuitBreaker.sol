// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

contract CircuitBreaker {
    event Stop();

    bool public live;

    constructor() {
        live = true;
    }

    modifier not_stopped() {
        require(live, "not live");
        _;
    }

    function _stop() internal {
        live = false;
        emit Stop();
    }
}
