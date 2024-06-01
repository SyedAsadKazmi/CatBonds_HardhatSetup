// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PositionToken} from "./PositionToken.sol";

contract CatastropheBond {
    error CatastropheBond__NotFactory();
    error CatastropheBond__NotCollateralPool();

    event CatastropheBondCreated(address indexed catastropheBond);

    struct PositionTokenMintedOnReceiverChain {
        uint256 chainId;
        address collateralPool;
        address catastropheBond;
        uint256 collateralLockedInUsdc;
        PositionToken.Position position;
        address minter;
        address caller; // for testing
    }

    struct PositionTokenRedeemedOnReceiverChain {
        uint256 chainId;
        address collateralPool;
        address catastropheBond;
        uint256 collateralRedeemedInUsdc;
        PositionToken.Position position;
        address redeemer;
        address caller; // for testing
    }

    enum SettledTo {
        NONE,
        ORACLE,
        FLOOR,
        CAP
    }

    SettledTo private s_settledTo;

    address immutable i_factory;
    address private immutable i_collateralPoolAddress;
    address private immutable i_longPositionToken;
    address private immutable i_shortPositionToken;

    string private s_catastropheCode;
    string private s_location;
    uint256 private immutable i_startDate_Timestamp;
    uint256 private immutable i_endDate_Timestamp;
    uint256 private immutable i_collateralRequiredForMintingAnyPositionToken;
    uint256 private immutable i_index;

    address private s_longPositionTokenHolder;
    address private s_shortPositionTokenHolder;

    uint256 private s_totalLongTokens;
    uint256 private s_totalShortTokens;

    bool private s_isLongPositionTokenMintedOnAnotherChain;
    bool private s_isShortPositionTokenMintedOnAnotherChain;

    bool private s_isLongPositionTokenRedeemedOnAnotherChain;
    bool private s_isShortPositionTokenRedeemedOnAnotherChain;

    bytes32
        private s_messageIdForPublishingMessageToBringUsdcCollateralFromAnotherChain;

    uint256 private s_collateralLockedForLongPosition;
    uint256 private s_collateralLockedForShortPosition;

    uint256 private s_collateralRedeemedForLongPosition;
    uint256 private s_collateralRedeemedForShortPosition;

    PositionTokenMintedOnReceiverChain[2]
        private s_positionTokensMintedOnReceiverChain; // 0 index for long, 1 index for short

    PositionTokenRedeemedOnReceiverChain[2]
        private s_positionTokensRedeemedOnReceiverChain; // 0 index for long, 1 index for short

    constructor(
        address collateralPoolAddress,
        string memory catastropheCode,
        string memory location,
        uint256 startDate_Timestamp,
        uint256 endDate_Timestamp,
        uint256 collateralRequiredForMintingAnyPositionToken,
        uint256 index
    ) {
        i_factory = msg.sender;
        i_collateralPoolAddress = collateralPoolAddress;
        s_catastropheCode = catastropheCode;
        s_location = location;
        i_startDate_Timestamp = startDate_Timestamp;
        i_endDate_Timestamp = endDate_Timestamp;
        i_collateralRequiredForMintingAnyPositionToken = collateralRequiredForMintingAnyPositionToken;
        i_index = index;

        // create long and short tokens
        PositionToken longPosToken = new PositionToken(
            "Cat-Bond Long Position Token",
            "LONG",
            uint8(PositionToken.Position.Long)
        );
        PositionToken shortPosToken = new PositionToken(
            "Cat-Bond Short Position Token",
            "SHORT",
            uint8(PositionToken.Position.Short)
        );

        i_longPositionToken = address(longPosToken);
        i_shortPositionToken = address(shortPosToken);
    }

    function mintPositionTokenOnReceiverChain(
        uint256 chainId,
        address catastropheBond,
        PositionToken.Position position,
        address collateralPool,
        uint256 collateralLockedInUsdc,
        address minter
    ) external onlyCollateralPool {
        if (position == PositionToken.Position.Long) {
            s_totalLongTokens += 1 ether;
            s_positionTokensMintedOnReceiverChain[0].chainId = chainId;
            s_positionTokensMintedOnReceiverChain[0]
                .collateralLockedInUsdc = collateralLockedInUsdc;
            s_positionTokensMintedOnReceiverChain[0].position = position;
            s_positionTokensMintedOnReceiverChain[0].minter = minter;
            s_positionTokensMintedOnReceiverChain[0]
                .collateralPool = collateralPool;
            s_positionTokensMintedOnReceiverChain[0]
                .catastropheBond = catastropheBond;
            s_positionTokensMintedOnReceiverChain[0].caller = msg.sender;

            s_isLongPositionTokenMintedOnAnotherChain = true;
            s_collateralLockedForLongPosition = collateralLockedInUsdc;
        } else if (position == PositionToken.Position.Short) {
            s_totalShortTokens += 1 ether;
            s_positionTokensMintedOnReceiverChain[1].chainId = chainId;
            s_positionTokensMintedOnReceiverChain[1]
                .collateralLockedInUsdc = collateralLockedInUsdc;
            s_positionTokensMintedOnReceiverChain[1].position = position;
            s_positionTokensMintedOnReceiverChain[1].minter = minter;
            s_positionTokensMintedOnReceiverChain[1]
                .collateralPool = collateralPool;
            s_positionTokensMintedOnReceiverChain[1]
                .catastropheBond = catastropheBond;
            s_positionTokensMintedOnReceiverChain[1].caller = msg.sender;

            s_isShortPositionTokenMintedOnAnotherChain = true;
            s_collateralLockedForShortPosition = collateralLockedInUsdc;
        }
    }

    function redeemPositionTokenOnReceiverChain(
        uint256 chainId,
        address catastropheBond,
        PositionToken.Position position,
        address collateralPool,
        uint256 collateralRedeemedInUsdc,
        address redeemer
    ) external onlyCollateralPool {
        if (position == PositionToken.Position.Long) {
            s_totalLongTokens -= 1 ether;
            s_positionTokensRedeemedOnReceiverChain[0].chainId = chainId;
            s_positionTokensRedeemedOnReceiverChain[0]
                .collateralRedeemedInUsdc = collateralRedeemedInUsdc;
            s_positionTokensRedeemedOnReceiverChain[0].position = position;
            s_positionTokensRedeemedOnReceiverChain[0].redeemer = redeemer;
            s_positionTokensRedeemedOnReceiverChain[0]
                .collateralPool = collateralPool;
            s_positionTokensRedeemedOnReceiverChain[0]
                .catastropheBond = catastropheBond;
            s_positionTokensRedeemedOnReceiverChain[0].caller = msg.sender;

            s_isLongPositionTokenRedeemedOnAnotherChain = true;
            s_collateralRedeemedForLongPosition = collateralRedeemedInUsdc;
        } else if (position == PositionToken.Position.Short) {
            s_totalShortTokens -= 1 ether;
            s_positionTokensRedeemedOnReceiverChain[1].chainId = chainId;
            s_positionTokensRedeemedOnReceiverChain[1]
                .collateralRedeemedInUsdc = collateralRedeemedInUsdc;
            s_positionTokensRedeemedOnReceiverChain[1].position = position;
            s_positionTokensRedeemedOnReceiverChain[1].redeemer = redeemer;
            s_positionTokensRedeemedOnReceiverChain[1]
                .collateralPool = collateralPool;
            s_positionTokensRedeemedOnReceiverChain[1]
                .catastropheBond = catastropheBond;
            s_positionTokensRedeemedOnReceiverChain[1].caller = msg.sender;

            s_isShortPositionTokenRedeemedOnAnotherChain = true;
            s_collateralRedeemedForShortPosition = collateralRedeemedInUsdc;
        }
    }

    /*
    // EXTERNAL - onlyCollateralPool METHODS
    */

    /// @notice called only by our collateral pool to create long position tokens
    /// @param qtyToMint    qty in base units of how many long tokens to mint
    /// @param minter       address of minter to receive tokens
    function mintLongToken(
        uint256 qtyToMint,
        address minter,
        uint256 collateral
    ) external onlyCollateralPool {
        PositionToken(i_longPositionToken).mintAndSendToken(qtyToMint, minter);
        s_totalLongTokens += qtyToMint;
        s_longPositionTokenHolder = minter;
        s_collateralLockedForLongPosition = collateral;
    }

    /// @notice called only by our collateral pool to create short position tokens
    /// @param qtyToMint    qty in base units of how many short tokens to mint
    /// @param minter       address of minter to receive tokens
    function mintShortToken(
        uint256 qtyToMint,
        address minter,
        uint256 collateral
    ) external onlyCollateralPool {
        PositionToken(i_shortPositionToken).mintAndSendToken(qtyToMint, minter);
        s_totalShortTokens += qtyToMint;
        s_shortPositionTokenHolder = minter;
        s_collateralLockedForShortPosition = collateral;
    }

    /// @notice called only by our collateral pool to redeem long position tokens
    /// @param qtyToRedeem  qty in base units of how many tokens to redeem
    /// @param redeemer     address of person redeeming tokens
    function redeemLongToken(
        uint256 qtyToRedeem,
        address redeemer,
        uint256 collateral
    ) external onlyCollateralPool {
        PositionToken(i_longPositionToken).redeemToken(qtyToRedeem, redeemer);

        s_totalLongTokens -= qtyToRedeem;

        s_collateralRedeemedForLongPosition = collateral;
    }

    /// @notice called only by our collateral pool to redeem short position tokens
    /// @param qtyToRedeem  qty in base units of how many tokens to redeem
    /// @param redeemer     address of person redeeming tokens
    function redeemShortToken(
        uint256 qtyToRedeem,
        address redeemer,
        uint256 collateral
    ) external onlyCollateralPool {
        PositionToken(i_shortPositionToken).redeemToken(qtyToRedeem, redeemer);

        s_totalShortTokens -= qtyToRedeem;

        s_collateralRedeemedForShortPosition = collateral;
    }

    function settleTo(uint256 settleToEnumValue) external onlyFactory {
        s_settledTo = SettledTo(settleToEnumValue);
    }

    function setMessageIdForPublishingMessageToBringUsdcCollateralFromAnotherChain(
        bytes32 messageId
    ) external onlyFactory {
        s_messageIdForPublishingMessageToBringUsdcCollateralFromAnotherChain = messageId;
    }

    /* 
    GETTERS
    */

    function getCatastropheCode() external view returns (string memory) {
        return s_catastropheCode;
    }

    function getLocation() external view returns (string memory) {
        return s_location;
    }

    function getStartDate_Timestamp() external view returns (uint256) {
        return i_startDate_Timestamp;
    }

    function getEndDate_Timestamp() external view returns (uint256) {
        return i_endDate_Timestamp;
    }

    function getCollateralRequiredForMintingAnyPositionToken()
        external
        view
        returns (uint256)
    {
        return i_collateralRequiredForMintingAnyPositionToken;
    }

    function getIndex() external view returns (uint256) {
        return i_index;
    }

    function settledTo() external view returns (SettledTo) {
        return s_settledTo;
    }

    function isSettled() external view returns (bool) {
        if (s_settledTo == SettledTo.NONE) return false;
        return true;
    }

    // returns the balance of long position token in the sender's account
    function getBalanceOfLongToken(
        address walletAddress
    ) external view returns (uint256) {
        return PositionToken(i_longPositionToken).balanceOf(walletAddress);
    }

    // returns the balance of short position token in the sender's account
    function getBalanceOfShortToken(
        address walletAddress
    ) external view returns (uint256) {
        return PositionToken(i_shortPositionToken).balanceOf(walletAddress);
    }

    function getCollateralPoolAddress() external view returns (address) {
        return i_collateralPoolAddress;
    }

    function getLongPositionToken() external view returns (address) {
        return i_longPositionToken;
    }

    function getShortPositionToken() external view returns (address) {
        return i_shortPositionToken;
    }

    function getLongPositionTokenHolder() external view returns (address) {
        return s_longPositionTokenHolder;
    }

    function getShortPositionTokenHolder() external view returns (address) {
        return s_shortPositionTokenHolder;
    }

    function getTotalLongTokens() external view returns (uint256) {
        return s_totalLongTokens;
    }

    function getTotalShortTokens() external view returns (uint256) {
        return s_totalShortTokens;
    }

    function getCollateralLockedForLongPosition()
        external
        view
        returns (uint256)
    {
        return s_collateralLockedForLongPosition;
    }

    function getCollateralLockedForShortPosition()
        external
        view
        returns (uint256)
    {
        return s_collateralLockedForShortPosition;
    }

    function getCollateralRedeemedForLongPosition()
        external
        view
        returns (uint256)
    {
        return s_collateralRedeemedForLongPosition;
    }

    function getCollateralRedeemedForShortPosition()
        external
        view
        returns (uint256)
    {
        return s_collateralRedeemedForShortPosition;
    }

    function getMessageIdForPublishingMessageToBringUsdcCollateralFromAnotherChain()
        external
        view
        returns (bytes32)
    {
        return
            s_messageIdForPublishingMessageToBringUsdcCollateralFromAnotherChain;
    }

    /***************************
    ****************************

    GETTERS (Another chain)

    ***************************
    ***************************/

    function isLongPositionTokenMintedOnAnotherChain()
        external
        view
        returns (bool)
    {
        return s_isLongPositionTokenMintedOnAnotherChain;
    }

    function isShortPositionTokenMintedOnAnotherChain()
        external
        view
        returns (bool)
    {
        return s_isShortPositionTokenMintedOnAnotherChain;
    }

    function isLongPositionTokenRedeemedOnAnotherChain()
        external
        view
        returns (bool)
    {
        return s_isLongPositionTokenRedeemedOnAnotherChain;
    }

    function isShortPositionTokenRedeemedOnAnotherChain()
        external
        view
        returns (bool)
    {
        return s_isShortPositionTokenRedeemedOnAnotherChain;
    }

    function getChainId_Minted_LongPositionTokenOnAnotherChain()
        external
        view
        returns (uint256)
    {
        return s_positionTokensMintedOnReceiverChain[0].chainId;
    }

    function getCollateralPool_Minted_LongPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensMintedOnReceiverChain[0].collateralPool;
    }

    function getCatastropheBond_Minted_LongPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensMintedOnReceiverChain[0].catastropheBond;
    }

    function getCollateralLockedInUsdc_LongPositionTokenOnAnotherChain()
        external
        view
        returns (uint256)
    {
        return s_positionTokensMintedOnReceiverChain[0].collateralLockedInUsdc;
    }

    function getMinter_LongPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensMintedOnReceiverChain[0].minter;
    }

    function getChainId_Minted_ShortPositionTokenOnAnotherChain()
        external
        view
        returns (uint256)
    {
        return s_positionTokensMintedOnReceiverChain[1].chainId;
    }

    function getCollateralPool_Minted_ShortPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensMintedOnReceiverChain[1].collateralPool;
    }

    function getCatastropheBond_Minted_ShortPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensMintedOnReceiverChain[1].catastropheBond;
    }

    function getCollateralLockedInUsdc_ShortPositionTokenOnAnotherChain()
        external
        view
        returns (uint256)
    {
        return s_positionTokensMintedOnReceiverChain[1].collateralLockedInUsdc;
    }

    function getMinter_ShortPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensMintedOnReceiverChain[1].minter;
    }

    function getChainId_Redeemed_LongPositionTokenOnAnotherChain()
        external
        view
        returns (uint256)
    {
        return s_positionTokensRedeemedOnReceiverChain[0].chainId;
    }

    function getCollateralPool_Redeemed_LongPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensRedeemedOnReceiverChain[0].collateralPool;
    }

    function getCatastropheBond_Redeemed_LongPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensRedeemedOnReceiverChain[0].catastropheBond;
    }

    function getCollateralRedeemedInUsdc_LongPositionTokenOnAnotherChain()
        external
        view
        returns (uint256)
    {
        return
            s_positionTokensRedeemedOnReceiverChain[0].collateralRedeemedInUsdc;
    }

    function getRedeemer_LongPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensRedeemedOnReceiverChain[0].redeemer;
    }

    function getChainId_Redeemed_ShortPositionTokenOnAnotherChain()
        external
        view
        returns (uint256)
    {
        return s_positionTokensRedeemedOnReceiverChain[1].chainId;
    }

    function getCollateralPool_Redeemed_ShortPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensRedeemedOnReceiverChain[1].collateralPool;
    }

    function getCatastropheBond_Redeemed_ShortPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensRedeemedOnReceiverChain[1].catastropheBond;
    }

    function getCollateralRedeemedInUsdc_ShortPositionTokenOnAnotherChain()
        external
        view
        returns (uint256)
    {
        return
            s_positionTokensRedeemedOnReceiverChain[1].collateralRedeemedInUsdc;
    }

    function getRedeemer_ShortPositionTokenOnAnotherChain()
        external
        view
        returns (address)
    {
        return s_positionTokensRedeemedOnReceiverChain[1].redeemer;
    }

    modifier onlyFactory() {
        if (msg.sender != i_factory) {
            revert CatastropheBond__NotFactory();
        }
        _;
    }

    /// @notice only able to be called directly by our collateral pool which controls the position tokens
    /// for this contract!
    modifier onlyCollateralPool() {
        if (msg.sender != i_collateralPoolAddress) {
            revert CatastropheBond__NotCollateralPool();
        }
        _;
    }
}
