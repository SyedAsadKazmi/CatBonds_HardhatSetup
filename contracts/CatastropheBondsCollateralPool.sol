// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CatastropheBond} from "./CatastropheBond.sol";
import {PositionToken} from "./PositionToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {NetworkConfig} from "./libraries/NetworkConfig.sol";

contract CatastropheBondsCollateralPool is CCIPReceiver {
    error CatastropheBondsCollateralPool__AllowanceLessThanCollateralNeeded(
        uint256 minimumRequirement
    );
    error CatastropheBondsCollateralPool__NotFundedWithEnoughLINK(
        uint256 minimumRequirement
    );
    error CatastropheBondsCollateralPool__InvalidReceiverCollateralPool();
    error CatastropheBondsCollateralPool__InvalidSenderCollateralPool();
    error CatastropheBondsCollateralPool__AlreadyRedeemed();
    error CatastropheBondsCollateralPool__NothingToRedeem();
    error CatastropheBondsCollateralPool__CatastropheBondIsNotSettledYet();
    error CatastropheBondsCollateralPool__FactoryNotSet();
    error CatastropheBondsCollateralPool__InsufficientCollateral(
        uint256 requiredCollateral
    );
    error CatastropheBondsCollateralPool__InsufficientUSDCBalance(
        uint256 minimumRequirement
    );
    error CatastropheBondsCollateralPool__FirstPublishMessageToBringCollateralLockedFor_ShortPosition();
    error CatastropheBondsCollateralPool__FirstPublishMessageToBringCollateralLockedFor_LongPosition();
    error CatastropheBondsCollateralPool__InvalidPosition();
    error CatastropheBondsCollateralPool__NotOwner();
    error CatastropheBondsCollateralPool__NeitherOwnerNorFactory();
    error CatastropheBondsCollateralPool__PositionTokenAlreadyMinted();

    struct ChainDetailsHavingUSDC {
        address collateralPool;
        uint64 chainSelector;
    }

    struct ReceiverChainDetails {
        address collateralPool; // That is supposed to receive message regarding position token being minted on another chain
        address catastropheBond;
        uint64 chainSelector;
    }

    address private immutable i_owner;
    IERC20 immutable i_usdcToken;
    LinkTokenInterface immutable i_linkToken;
    IRouterClient immutable i_routerForCCIP;
    bool private s_isMessagePublished_tobringCollateralLockedFor_ShortPosition;
    bool private s_isMessagePublished_tobringCollateralLockedFor_LongPosition;
    address private s_catastropheBondsFactory;

    mapping(address => uint256)
        private s_catastropheBondToCollateralPoolBalance; // current balance of all collateral committed

    event MessageSent(bytes32 messageId);

    event TokensMinted(
        address indexed catastropheBond,
        address indexed user,
        uint256 qtyMinted,
        uint256 collateralLockedInUsdc
    );

    event TokensRedeemed(
        address indexed catastropheBond,
        address indexed user,
        uint256 qtyRedeemed,
        string tokenType,
        uint256 collateralReturnedInUsdc,
        bool withProfit
    );

    event CallSuccessfullOnReceiverChain();

    constructor()
        CCIPReceiver(NetworkConfig.getRouterAddressForCCIP(block.chainid))
    {
        i_owner = msg.sender;
        i_routerForCCIP = IRouterClient(
            NetworkConfig.getRouterAddressForCCIP(block.chainid)
        );
        i_usdcToken = IERC20(NetworkConfig.getUsdcTokenAddress(block.chainid));
        i_linkToken = LinkTokenInterface(
            NetworkConfig.getLinkTokenAddress(block.chainid)
        );
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        if (message.data.length > 0) {
            (bool success, ) = address(this).call(message.data);
            require(success);
        }

        emit CallSuccessfullOnReceiverChain();
    }

    function mintPositionTokenOnReceiverChain(
        address collateralPool_receiver, // Collateral Pool address on the chain which needs to be aware of the minted position
        uint256 chainId_source, // Chain id of chain on which position token is minted
        address catastropheBondAddress_source, // CatastropheBonds address on the chain on which position token is minted
        address catastropheBondAddress_receiver, // CatastropheBonds address on the chain which needs to be aware of the minted position
        uint8 mintedPosition_source, // position which is minted on source chain
        address collateralPool_source, // Collateral Pool address on the chain on which position token is minted
        uint256 collateralLockedInUsdc_source, // collateral locked in USDC for minting position on source chain
        address minter_source // who has minted the position on the source chain
    ) public {
        if (msg.sender != collateralPool_receiver) {
            revert CatastropheBondsCollateralPool__InvalidReceiverCollateralPool();
        }
        CatastropheBond catastropheBond = CatastropheBond(
            catastropheBondAddress_receiver
        );

        s_catastropheBondToCollateralPoolBalance[
            catastropheBondAddress_receiver
        ] += collateralLockedInUsdc_source;

        catastropheBond.mintPositionTokenOnReceiverChain(
            chainId_source,
            catastropheBondAddress_source,
            PositionToken.Position(mintedPosition_source),
            collateralPool_source,
            collateralLockedInUsdc_source,
            minter_source
        );
    }

    function redeemPositionTokenOnReceiverChain(
        address collateralPool_receiver, // Collateral Pool address on the chain which needs to be aware of the redeemed position
        uint256 chainId_source, // Chain id of chain on which position token is redeemed
        address catastropheBondAddress_source, // CatastropheBonds address on the chain on which position token is redeemed
        address catastropheBondAddress_receiver, // CatastropheBonds address on the chain which needs to be aware of the redeemed position
        uint8 redeemedPosition_source, // position which is redeemed on source chain
        address collateralPool_source, // Collateral Pool address on the chain on which position token is minted
        uint256 collateralRedeemedInUsdc_source, // collateral redeemed in USDC for redeeming position on source chain
        address redeemer_source // who has redeemed the position on the source chain
    ) public {
        if (msg.sender != collateralPool_receiver) {
            revert CatastropheBondsCollateralPool__InvalidReceiverCollateralPool();
        }
        CatastropheBond catastropheBond = CatastropheBond(
            catastropheBondAddress_receiver
        );

        s_catastropheBondToCollateralPoolBalance[
            catastropheBondAddress_receiver
        ] -= collateralRedeemedInUsdc_source;

        catastropheBond.redeemPositionTokenOnReceiverChain(
            chainId_source,
            catastropheBondAddress_source,
            PositionToken.Position(redeemedPosition_source),
            collateralPool_source,
            collateralRedeemedInUsdc_source,
            redeemer_source
        );
    }

    function publishMintingMessageToAnotherChain(
        address catastropheBondAddress,
        uint256 collateralLockedInUsdc,
        PositionToken.Position position,
        ReceiverChainDetails memory receiverChainDetails
    ) internal {
        bytes4 selector = this.mintPositionTokenOnReceiverChain.selector;
        bytes memory data = abi.encodeWithSelector(
            selector,
            receiverChainDetails.collateralPool,
            block.chainid,
            catastropheBondAddress,
            receiverChainDetails.catastropheBond,
            uint8(position),
            address(this),
            collateralLockedInUsdc,
            msg.sender
        );
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverChainDetails.collateralPool),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 1_000_000})
            ),
            feeToken: address(i_linkToken)
        });

        uint256 fee = i_routerForCCIP.getFee(
            receiverChainDetails.chainSelector,
            message
        );

        if (i_linkToken.balanceOf(address(this)) < fee) {
            revert CatastropheBondsCollateralPool__NotFundedWithEnoughLINK(fee);
        }

        bytes32 messageId;

        uint256 allowance = i_linkToken.allowance(
            address(this),
            address(i_routerForCCIP)
        );

        if (allowance < fee) {
            i_linkToken.approve(address(i_routerForCCIP), fee);
        }

        messageId = i_routerForCCIP.ccipSend(
            receiverChainDetails.chainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    function publishRedeemingMessageToAnotherChain(
        address catastropheBondAddress,
        uint256 collateralRedeemedInUsdc,
        PositionToken.Position position,
        ReceiverChainDetails memory receiverChainDetails
    ) internal {
        bytes4 selector = this.redeemPositionTokenOnReceiverChain.selector;
        bytes memory data = abi.encodeWithSelector(
            selector,
            receiverChainDetails.collateralPool,
            block.chainid,
            catastropheBondAddress,
            receiverChainDetails.catastropheBond,
            uint8(position),
            address(this),
            collateralRedeemedInUsdc,
            msg.sender
        );
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverChainDetails.collateralPool),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 1_000_000})
            ),
            feeToken: address(i_linkToken)
        });

        uint256 fee = i_routerForCCIP.getFee(
            receiverChainDetails.chainSelector,
            message
        );

        if (i_linkToken.balanceOf(address(this)) < fee) {
            revert CatastropheBondsCollateralPool__NotFundedWithEnoughLINK(fee);
        }

        bytes32 messageId;

        uint256 allowance = i_linkToken.allowance(
            address(this),
            address(i_routerForCCIP)
        );

        if (allowance < fee) {
            i_linkToken.approve(address(i_routerForCCIP), fee);
        }

        messageId = i_routerForCCIP.ccipSend(
            receiverChainDetails.chainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    // address public callerOfPublishMessageToBringUsdcCollateralFromAnotherChain; // for testing

    function publishMessageToBringUsdcCollateralFromAnotherChain(
        address catastropheBondAddress, // where to bring USDC back
        PositionToken.Position position // which is minted on another chain
    ) external onlyOwnerOrFactory returns (bytes32) {
        // callerOfPublishMessageToBringUsdcCollateralFromAnotherChain = msg
        //     .sender;

        CatastropheBond catastropheBond = CatastropheBond(
            catastropheBondAddress
        );

        uint256 amount;

        uint64 chainSelectorOfCurrentChain = NetworkConfig.getChainSelector(
            block.chainid
        );

        ChainDetailsHavingUSDC memory chainDetailsHavingUSDC;

        if (position == PositionToken.Position.Long) {
            amount = catastropheBond.getCollateralLockedForLongPosition();
            // Preparing chain details having USDC
            uint64 chainSelector_havingUSDC = NetworkConfig.getChainSelector(
                catastropheBond
                    .getChainId_Minted_LongPositionTokenOnAnotherChain()
            );
            address collateralPool_havingUSDC = catastropheBond
                .getCollateralPool_Minted_LongPositionTokenOnAnotherChain();

            chainDetailsHavingUSDC = ChainDetailsHavingUSDC({
                collateralPool: collateralPool_havingUSDC,
                chainSelector: chainSelector_havingUSDC
            });

            s_isMessagePublished_tobringCollateralLockedFor_LongPosition = true;
        } else if (position == PositionToken.Position.Short) {
            amount = catastropheBond.getCollateralLockedForShortPosition();

            // Preparing chain details having USDC
            uint64 chainSelector_havingUSDC = NetworkConfig.getChainSelector(
                catastropheBond
                    .getChainId_Minted_ShortPositionTokenOnAnotherChain()
            );
            address collateralPool_havingUSDC = catastropheBond
                .getCollateralPool_Minted_ShortPositionTokenOnAnotherChain();

            chainDetailsHavingUSDC = ChainDetailsHavingUSDC({
                collateralPool: collateralPool_havingUSDC,
                chainSelector: chainSelector_havingUSDC
            });

            s_isMessagePublished_tobringCollateralLockedFor_ShortPosition = true;
        } else {
            revert CatastropheBondsCollateralPool__InvalidPosition();
        }
        bytes4 selector = this.bringUsdcCollateralFromAnotherChain.selector;
        bytes memory data = abi.encodeWithSelector(
            selector,
            chainDetailsHavingUSDC.collateralPool,
            address(this),
            chainSelectorOfCurrentChain,
            amount
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(chainDetailsHavingUSDC.collateralPool),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 1_000_000})
            ),
            feeToken: address(i_linkToken)
        });

        uint256 fee = i_routerForCCIP.getFee(
            chainDetailsHavingUSDC.chainSelector,
            message
        );

        if (i_linkToken.balanceOf(address(this)) < fee) {
            revert CatastropheBondsCollateralPool__NotFundedWithEnoughLINK(fee);
        }

        bytes32 messageId;

        uint256 allowance = i_linkToken.allowance(
            address(this),
            address(i_routerForCCIP)
        );

        if (allowance < fee) {
            i_linkToken.approve(address(i_routerForCCIP), fee);
        }

        messageId = i_routerForCCIP.ccipSend(
            chainDetailsHavingUSDC.chainSelector,
            message
        );

        emit MessageSent(messageId);

        return messageId;
    }

    function bringUsdcCollateralFromAnotherChain(
        address collateralPool_havingUSDC,
        address collateralPool_Receiver, // Collateral Pool Address of the chain receiving USDC
        uint64 chainSelector, // Where to bring USDC back
        uint256 amountOfUsdc
    ) public {
        if (msg.sender != collateralPool_havingUSDC) {
            revert CatastropheBondsCollateralPool__InvalidSenderCollateralPool();
        }
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(i_usdcToken),
            amount: amountOfUsdc
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(collateralPool_Receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            extraArgs: "",
            feeToken: address(i_linkToken)
        });

        if (i_usdcToken.balanceOf(address(this)) < amountOfUsdc) {
            revert CatastropheBondsCollateralPool__InsufficientUSDCBalance(
                amountOfUsdc
            );
        }

        uint256 usdc_allowance = i_usdcToken.allowance(
            address(this),
            address(i_routerForCCIP)
        );

        if (usdc_allowance < amountOfUsdc) {
            // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
            i_usdcToken.approve(address(i_routerForCCIP), amountOfUsdc);
        }

        uint256 fee = i_routerForCCIP.getFee(chainSelector, message);

        if (i_linkToken.balanceOf(address(this)) < fee) {
            revert CatastropheBondsCollateralPool__NotFundedWithEnoughLINK(fee);
        }

        uint256 allowance = i_linkToken.allowance(
            address(this),
            address(i_routerForCCIP)
        );

        if (allowance < fee) {
            i_linkToken.approve(address(i_routerForCCIP), fee);
        }

        bytes32 messageId;

        messageId = i_routerForCCIP.ccipSend(chainSelector, message);

        emit MessageSent(messageId);
    }

    /// @notice Called by a user that would like to mint a new set of long token for a specified
    /// catastropheBond contract.  This will transfer and lock the correct amount of collateral into the pool
    /// and issue them one long position token
    /// @param catastropheBondAddress          address of the catastropheBond contract to mint long position token for

    function mintLongPositionToken(
        address catastropheBondAddress,
        // uint256 neededCollateral,
        ReceiverChainDetails memory receiverChainDetails // ["Other Collateral Pool Address","Other CatastropheBond Address",16015286601757825753]
    ) external {
        if (s_catastropheBondsFactory == address(0))
            revert CatastropheBondsCollateralPool__FactoryNotSet();
        CatastropheBond catastropheBond = CatastropheBond(
            catastropheBondAddress
        );

        uint256 neededCollateral = catastropheBond
            .getCollateralRequiredForMintingAnyPositionToken();

        // require(
        //     catastropheBond.getTotalLongTokens() == 0,
        //     "Long position token is already minted"
        // );

        if (catastropheBond.getTotalLongTokens() != 0)
            revert CatastropheBondsCollateralPool__PositionTokenAlreadyMinted();

        if (catastropheBond.getTotalShortTokens() != 0) {
            // Collateral should be equal to what's being used to mint short token
            if (
                neededCollateral !=
                catastropheBond.getCollateralLockedForShortPosition()
            ) {
                revert CatastropheBondsCollateralPool__InsufficientCollateral(
                    catastropheBond.getCollateralLockedForShortPosition()
                );
            }
        }

        uint256 allowance = i_usdcToken.allowance(msg.sender, address(this));

        if (allowance < neededCollateral) {
            revert CatastropheBondsCollateralPool__AllowanceLessThanCollateralNeeded(
                neededCollateral
            );
        }

        i_usdcToken.transferFrom(msg.sender, address(this), neededCollateral);

        // update the collateral pool locked balance
        s_catastropheBondToCollateralPoolBalance[
            catastropheBondAddress
        ] += neededCollateral;

        // mint and distribute long position token to our caller
        catastropheBond.mintLongToken(1 ether, msg.sender, neededCollateral);

        publishMintingMessageToAnotherChain(
            catastropheBondAddress,
            neededCollateral,
            PositionToken.Position.Long,
            receiverChainDetails
        );

        emit TokensMinted(
            catastropheBondAddress,
            msg.sender,
            1 ether,
            neededCollateral
        );
    }

    /// @notice Called by a user that would like to mint a new set of short token for a specified
    /// catastropheBond contract.  This will transfer and lock the correct amount of collateral into the pool
    /// and issue them one short position token
    /// @param catastropheBondAddress          address of the catastropheBond contract to mint short position token for
    function mintShortPositionToken(
        address catastropheBondAddress,
        // uint256 neededCollateral,
        ReceiverChainDetails memory receiverChainDetails
    ) external {
        if (s_catastropheBondsFactory == address(0))
            revert CatastropheBondsCollateralPool__FactoryNotSet();

        CatastropheBond catastropheBond = CatastropheBond(
            catastropheBondAddress
        );

        uint256 neededCollateral = catastropheBond
            .getCollateralRequiredForMintingAnyPositionToken();

        // require(
        //     catastropheBond.getTotalShortTokens() == 0,
        //     "Short position token is already minted"
        // );

        if (catastropheBond.getTotalShortTokens() != 0)
            revert CatastropheBondsCollateralPool__PositionTokenAlreadyMinted();

        if (catastropheBond.getTotalLongTokens() != 0) {
            // Collateral should be equal to what's being used to mint long token
            if (
                neededCollateral !=
                catastropheBond.getCollateralLockedForLongPosition()
            ) {
                revert CatastropheBondsCollateralPool__InsufficientCollateral(
                    catastropheBond.getCollateralLockedForLongPosition()
                );
            }
        }

        uint256 allowance = i_usdcToken.allowance(msg.sender, address(this));

        if (allowance < neededCollateral) {
            revert CatastropheBondsCollateralPool__AllowanceLessThanCollateralNeeded(
                neededCollateral
            );
        }

        i_usdcToken.transferFrom(msg.sender, address(this), neededCollateral);

        // update the collateral pool locked balance
        s_catastropheBondToCollateralPoolBalance[
            catastropheBondAddress
        ] += neededCollateral;

        // mint and distribute short position token to our caller
        catastropheBond.mintShortToken(1 ether, msg.sender, neededCollateral);

        publishMintingMessageToAnotherChain(
            catastropheBondAddress,
            neededCollateral,
            PositionToken.Position.Short,
            receiverChainDetails
        );

        emit TokensMinted(
            catastropheBondAddress,
            msg.sender,
            1 ether,
            neededCollateral
        );
    }

    /// @notice Called by a user that currently holds either long or short position token and would like to redeem either of them for the collateral
    /// @param catastropheBondAddress            address of the catastropheBond contract to redeem long or short position token for
    function redeemPositionToken(
        address catastropheBondAddress,
        // uint256 settledToState, // for testing
        ReceiverChainDetails memory receiverChainDetails
    )
        external
    // uint64 chainSelectorOfCurrentChain, // where to bring USDC back
    // ChainDetailsHavingUSDC memory chainDetailsHavingUSDC // having USDC
    {
        /*
        0 -> NONE
        1 -> ORACLE
        2 -> FLOOR
        3 -> CAP
        */

        CatastropheBond catastropheBond = CatastropheBond(
            catastropheBondAddress
        );

        if (!catastropheBond.isSettled())
            revert CatastropheBondsCollateralPool__CatastropheBondIsNotSettledYet();

        CatastropheBond.SettledTo settledTo = catastropheBond.settledTo();
        uint256 collateralRedeemedInUsdc;

        if (
            catastropheBond.getTotalShortTokens() != 1 ether &&
            catastropheBond.getTotalLongTokens() != 1 ether
        ) {
            revert CatastropheBondsCollateralPool__AlreadyRedeemed();
        }

        if (
            catastropheBond.getBalanceOfLongToken(msg.sender) == 0 &&
            catastropheBond.getBalanceOfShortToken(msg.sender) == 0
        ) {
            revert CatastropheBondsCollateralPool__NothingToRedeem();
        }

        bool positionTokensRedeemed = false;

        // calculate collateral to return
        uint256 collateralLocked = s_catastropheBondToCollateralPoolBalance[
            catastropheBondAddress
        ];

        if (
            settledTo == CatastropheBond.SettledTo.CAP &&
            catastropheBond.getBalanceOfLongToken(msg.sender) == 1 ether // means long token is minted on this chain
        ) {
            // transfer 95% of the total collateral to redeemer
            uint256 collateralToRedeem = (95 * collateralLocked) / 100;

            // transfer remaining (i.e. 5%) collateral to owner
            uint256 ownerProfit = collateralLocked - collateralToRedeem;

            // check whether the short token is minted on another chain
            if (catastropheBond.isShortPositionTokenMintedOnAnotherChain()) {
                if (
                    !s_isMessagePublished_tobringCollateralLockedFor_ShortPosition
                ) {
                    revert CatastropheBondsCollateralPool__FirstPublishMessageToBringCollateralLockedFor_ShortPosition();
                }
            }

            // need to wait for receiving message/funds

            i_usdcToken.transfer(msg.sender, collateralToRedeem);

            i_usdcToken.transfer(i_owner, ownerProfit);

            // update pool balance
            s_catastropheBondToCollateralPoolBalance[
                catastropheBondAddress
            ] -= collateralLocked;

            emit TokensRedeemed(
                catastropheBondAddress,
                msg.sender,
                1 ether,
                "LONG",
                collateralToRedeem,
                true
            );

            catastropheBond.redeemLongToken(
                1 ether,
                msg.sender,
                collateralToRedeem
            );

            positionTokensRedeemed = true;

            collateralRedeemedInUsdc = collateralToRedeem;

            publishRedeemingMessageToAnotherChain(
                catastropheBondAddress,
                collateralRedeemedInUsdc,
                PositionToken.Position.Long,
                receiverChainDetails
            );
        } else if (
            settledTo == CatastropheBond.SettledTo.FLOOR &&
            catastropheBond.getBalanceOfShortToken(msg.sender) == 1 ether
        ) {
            // transfer 95% of the total collateral to redeemer
            uint256 collateralToRedeem = (95 * collateralLocked) / 100;

            // transfer remaining (i.e. 5%) collateral to owner
            uint256 ownerProfit = collateralLocked - collateralToRedeem;

            // check whether the long token is minted on another chain
            if (catastropheBond.isLongPositionTokenMintedOnAnotherChain()) {
                if (
                    !s_isMessagePublished_tobringCollateralLockedFor_LongPosition
                ) {
                    revert CatastropheBondsCollateralPool__FirstPublishMessageToBringCollateralLockedFor_LongPosition();
                }
            }

            // need to wait for receiving message/funds

            i_usdcToken.transfer(msg.sender, collateralToRedeem);

            i_usdcToken.transfer(i_owner, ownerProfit);

            s_catastropheBondToCollateralPoolBalance[
                catastropheBondAddress
            ] -= collateralLocked;

            emit TokensRedeemed(
                catastropheBondAddress,
                msg.sender,
                1 ether,
                "SHORT",
                collateralToRedeem,
                true
            );

            catastropheBond.redeemShortToken(
                1 ether,
                msg.sender,
                collateralToRedeem
            );

            positionTokensRedeemed = true;

            collateralRedeemedInUsdc = collateralToRedeem;

            publishRedeemingMessageToAnotherChain(
                catastropheBondAddress,
                collateralRedeemedInUsdc,
                PositionToken.Position.Short,
                receiverChainDetails
            );
        } else {
            if (catastropheBond.getBalanceOfLongToken(msg.sender) == 1 ether) {
                if (settledTo == CatastropheBond.SettledTo.ORACLE) {
                    // transfer collateral (equivalent to what he'd originally put) back to redeemer
                    i_usdcToken.transfer(
                        msg.sender,
                        catastropheBond.getCollateralLockedForLongPosition()
                    );

                    s_catastropheBondToCollateralPoolBalance[
                        catastropheBondAddress
                    ] -= catastropheBond.getCollateralLockedForLongPosition();

                    catastropheBond.redeemLongToken(
                        1 ether,
                        msg.sender,
                        catastropheBond.getCollateralLockedForLongPosition()
                    );
                    positionTokensRedeemed = true;

                    emit TokensRedeemed(
                        catastropheBondAddress,
                        msg.sender,
                        1 ether,
                        "LONG",
                        catastropheBond.getCollateralLockedForLongPosition(),
                        false
                    );

                    collateralRedeemedInUsdc = catastropheBond
                        .getCollateralLockedForLongPosition();
                } else {
                    catastropheBond.redeemLongToken(1 ether, msg.sender, 0);
                    positionTokensRedeemed = true;

                    emit TokensRedeemed(
                        catastropheBondAddress,
                        msg.sender,
                        1 ether,
                        "LONG",
                        0,
                        false
                    );

                    collateralRedeemedInUsdc = 0;
                }

                publishRedeemingMessageToAnotherChain(
                    catastropheBondAddress,
                    collateralRedeemedInUsdc,
                    PositionToken.Position.Long,
                    receiverChainDetails
                );
            }
            if (catastropheBond.getBalanceOfShortToken(msg.sender) == 1 ether) {
                if (settledTo == CatastropheBond.SettledTo.ORACLE) {
                    // transfer collateral (equivalent to what he'd originally put) back to redeemer
                    i_usdcToken.transfer(
                        msg.sender,
                        catastropheBond.getCollateralLockedForShortPosition()
                    );

                    s_catastropheBondToCollateralPoolBalance[
                        catastropheBondAddress
                    ] -= catastropheBond.getCollateralLockedForShortPosition();

                    catastropheBond.redeemShortToken(
                        1 ether,
                        msg.sender,
                        catastropheBond.getCollateralLockedForShortPosition()
                    );
                    positionTokensRedeemed = true;

                    emit TokensRedeemed(
                        catastropheBondAddress,
                        msg.sender,
                        1 ether,
                        "SHORT",
                        catastropheBond.getCollateralLockedForShortPosition(),
                        false
                    );

                    collateralRedeemedInUsdc = catastropheBond
                        .getCollateralLockedForShortPosition();
                } else {
                    catastropheBond.redeemShortToken(1 ether, msg.sender, 0);
                    positionTokensRedeemed = true;

                    emit TokensRedeemed(
                        catastropheBondAddress,
                        msg.sender,
                        1 ether,
                        "SHORT",
                        0,
                        false
                    );

                    collateralRedeemedInUsdc = 0;
                }

                publishRedeemingMessageToAnotherChain(
                    catastropheBondAddress,
                    collateralRedeemedInUsdc,
                    PositionToken.Position.Short,
                    receiverChainDetails
                );
            }
        }
    }

    /* SETTERS */
    function setCatastropheBondsFactory(address factory) external onlyOwner {
        s_catastropheBondsFactory = factory;
    }

    /* GETTERS */
    function getCatastropheBondsFactory() external view returns (address) {
        return s_catastropheBondsFactory;
    }

    function getCurrentNetworkName()
        external
        view
        returns (string memory networkName)
    {
        if (block.chainid == 43113) {
            networkName = "Avalanche Fuji";
        } else if (block.chainid == 80002) {
            networkName = "Polygon Amoy";
        }
    }

    function isMessagePublished_tobringCollateralLockedFor_ShortPosition()
        external
        view
        returns (bool)
    {
        return s_isMessagePublished_tobringCollateralLockedFor_ShortPosition;
    }

    function isMessagePublished_tobringCollateralLockedFor_LongPosition()
        external
        view
        returns (bool)
    {
        return s_isMessagePublished_tobringCollateralLockedFor_LongPosition;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getCollateralBalanceOfCatastropheBond(
        address catastropheBond
    ) external view returns (uint256) {
        return s_catastropheBondToCollateralPoolBalance[catastropheBond];
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert CatastropheBondsCollateralPool__NotOwner();
        }
        _;
    }

    modifier onlyOwnerOrFactory() {
        if (msg.sender != i_owner && msg.sender != s_catastropheBondsFactory) {
            revert CatastropheBondsCollateralPool__NeitherOwnerNorFactory();
        }
        _;
    }
}
