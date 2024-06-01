// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PositionToken is ERC20 {
    string _name;
    string _symbol;
    uint8 _decimals;
    address private owner;

    Position public POSITION; // 0 = Long, 1 = Short
    enum Position {
        Long,
        Short
    }

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 position
    ) ERC20(tokenName, tokenSymbol) {
        owner = msg.sender;
        _name = tokenName;
        _symbol = tokenSymbol;
        _decimals = 18;
        POSITION = Position(position);
    }

    /// @dev Called by our EcoFuturesContract (owner) to create a long or short position token. These tokens are minted,
    /// and then transferred to our recipient who is the party who is minting these tokens.  The collateral pool
    /// is the only caller (acts as the owner) because collateral must be deposited / locked prior to minting of new
    /// position tokens
    /// @param qtyToMint quantity of position tokens to mint (in base units)
    /// @param recipient the person minting and receiving these position tokens.
    function mintAndSendToken(uint256 qtyToMint, address recipient) external {
        require(msg.sender == owner);
        _mint(recipient, qtyToMint);
    }

    /// @dev Called by our EcoFuturesContract (owner) when redemption occurs.  This means that either a single user is redeeming
    /// both short and long tokens in order to claim their collateral, or the contract has settled, and only a single
    /// side of the tokens are needed to redeem (handled by the collateral pool)
    /// @param qtyToRedeem quantity of tokens to burn (remove from supply / circulation)
    /// @param redeemer the person redeeming these tokens (who are we taking the balance from)
    function redeemToken(uint256 qtyToRedeem, address redeemer) external {
        require(msg.sender == owner);
        _burn(redeemer, qtyToRedeem);
    }
}
