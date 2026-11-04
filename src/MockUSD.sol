// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title MockUSD: testnet-only 6-decimal settlement token (no value)
contract MockUSD {
    string public constant name = "Mock USD (testnet)";
    string public constant symbol = "mUSD";
    uint8 public constant decimals = 6;
    uint256 public totalSupply;
    address public immutable owner;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    constructor() { owner = msg.sender; }
    function mint(address to, uint256 v) external { require(msg.sender == owner, "owner"); totalSupply += v; balanceOf[to] += v; emit Transfer(address(0), to, v); }
    function transfer(address to, uint256 v) external returns (bool) { return _t(msg.sender, to, v); }
    function approve(address s, uint256 v) external returns (bool) { allowance[msg.sender][s] = v; emit Approval(msg.sender, s, v); return true; }
    function transferFrom(address f, address to, uint256 v) external returns (bool) { allowance[f][msg.sender] -= v; return _t(f, to, v); }
    function _t(address f, address to, uint256 v) internal returns (bool) { balanceOf[f] -= v; balanceOf[to] += v; emit Transfer(f, to, v); return true; }
}
