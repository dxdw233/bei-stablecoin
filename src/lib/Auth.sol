// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

contract Auth {
    event GrantAuthorization(address indexed usr);
    event DenyAuthorization(address indexed usr);

    // --- Auth ---
    mapping(address => bool) public authorized;

    constructor() {
        authorized[msg.sender] = true;
        emit GrantAuthorization(msg.sender);
    }

    // rely
    function grant_auth(address usr) external auth {
        authorized[usr] = true;
        emit GrantAuthorization(usr);
    }

    // deny
    function deny_auth(address usr) external auth {
        authorized[usr] = false;
        emit DenyAuthorization(usr);
    }

    modifier auth() {
        require(authorized[msg.sender] == true, "not authorized");
        _;
    }
}
