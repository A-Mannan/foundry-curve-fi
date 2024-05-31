// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICurveStableSwapMetaNG {

    // AMM Main Functions
    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    ) external returns (uint256);

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    ) external returns (uint256);

    function exchange_received(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    ) external returns (uint256);

    function add_liquidity(
        uint256[2] calldata _amounts,
        uint256 _min_mint_amount,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_received,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity_imbalance(
        uint256[] calldata _amounts,
        uint256 _max_burn_amount,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity(
        uint256 _burn_amount,
        uint256[2] calldata _min_amounts,
        address _receiver,
        bool _claim_admin_fees
    ) external returns (uint256[2] memory);

    function withdraw_admin_fees() external;

    function balances(uint256 i) external view returns (uint256);

    // ERC20 Functions
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
