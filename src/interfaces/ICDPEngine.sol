// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

// VatLike
interface ICDPEngine {
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

    // --- Auth ---
    // wards
    function authorized(address user) external view returns (bool);

    // rely
    function grant_auth(address user) external;

    // deny
    function deny_auth(address user) external;

    // can
    function can(address owner, address user) external view returns (bool);

    // --- Data ---
    // ilks
    function collaterals(bytes32 col_type) external view returns (Collateral memory);

    // urns
    function positions(bytes32 col_type, address account) external view returns (Position memory);

    // gem [wad]
    function gem(bytes32 col_type, address account) external view returns (uint256);

    // dai [rad]
    function coin(address account) external view returns (uint256);

    // debt [rad]
    function sys_debt() external view returns (uint256);

    // Line [rad]
    function sys_max_debt() external view returns (uint256);

    // init
    function init(bytes32 col_type) external view;

    // file
    function set(bytes32 key, uint256 val) external;

    // file
    function set(bytes32 col_type, bytes32 key, uint256 val) external;

    // cage
    function cage() external;

    // hope
    function allow_account_modification(address user) external;

    // nope
    function deny_account_modification(address user) external;

    // wish
    function can_modify_account(address owner, address user) external view returns (bool);

    // move
    function transfer_coin(address src, address dst, uint256 rad) external;

    // slip
    function modify_collateral_balance(bytes32 col_type, address user, int256 wad) external;

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
    ) external;

    // fold
    function fold(bytes32 col_type, address coin_dst, int256 delta_rate) external;

    // suck
    function mint(address debt_dst, address coin_dst, uint256 rad) external;
}
