// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CatastropheBond} from "./CatastropheBond.sol";

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsSource} from "./libraries/CatastropheBondsFunctionsSource.sol";
import {Typecast} from "./libraries/Typecast.sol";
import {NetworkConfig} from "./libraries/NetworkConfig.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {CatastropheBondsCollateralPool} from "./CatastropheBondsCollateralPool.sol";
import {PositionToken} from "./PositionToken.sol";

contract CatastropheBondsFactory is
    CCIPReceiver,
    FunctionsClient,
    AutomationCompatible
{
    using FunctionsRequest for FunctionsRequest.Request;
    using Typecast for uint256;

    error CatastropheBondsFactory__ReceiverChainDetailsCannotBeEmptyWhilePublishingMessageToAnotherChain();
    error CatastropheBondsFactory__NotFundedWithEnoughLINK(
        uint256 minimumRequirement
    );
    error CatastropheBondsFactory__RequestNotYetFulfilled();
    error CatastropheBondsFactory__FactoryNotSetInCollateralPool();
    error CatastropheBondsFactory__NotOwner();
    error CatastropheBondsFactory__NeitherOwnerNorForwarder();
    error CatastropheBondsFactory__ForwarderNotSet();

    event CatastropheBondCreated(address indexed catastropheBond);
    event CallSuccessfullOnReceiverChain();
    event MessageSent(bytes32 messageId);

    uint256 constant SECONDS_IN_ONE_DAY = 86400;
    address immutable i_owner;
    LinkTokenInterface immutable i_linkToken;
    IRouterClient immutable i_routerForCCIP;
    address immutable i_routerAddressForChainlinkFunctions;

    address private immutable i_collateralPoolAddress;
    address[] private s_catastropheBonds;
    address private s_forwarder;

    // Event to log responses
    event Response(
        bytes32 indexed requestId,
        address catastropheBondAddress,
        bytes response,
        bytes err
    );

    struct ReceiverChainDetails {
        address catastropheBondsFactory; // That is supposed to receive message to create catastrophe bond on another chain
        address collateralPool;
        uint64 chainSelector;
    }

    mapping(bytes32 => address) private s_requestIdToCatastropheBondAddress;
    mapping(address => bytes32) private s_catastropheBondAddressToRequestId;

    constructor(
        address collateralPoolAddress
    )
        CCIPReceiver(NetworkConfig.getRouterAddressForCCIP(block.chainid))
        FunctionsClient(
            NetworkConfig.getRouterAddressForChainlinkFunctions(block.chainid)
        )
    {
        i_collateralPoolAddress = collateralPoolAddress;
        i_owner = msg.sender;
        i_routerForCCIP = IRouterClient(
            NetworkConfig.getRouterAddressForCCIP(block.chainid)
        );
        i_routerAddressForChainlinkFunctions = NetworkConfig
            .getRouterAddressForChainlinkFunctions(block.chainid);
        i_linkToken = LinkTokenInterface(
            NetworkConfig.getLinkTokenAddress(block.chainid)
        );
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (bool success, ) = address(this).call(message.data);
        require(success);
        emit CallSuccessfullOnReceiverChain();
    }

    function createCatastropheBond(
        address collateralPoolAddress,
        string memory catastropheCode,
        string memory location,
        uint256 startDateTimestamp,
        uint256 endDateTimestamp,
        uint256 collateralRequiredForMintingAnyPositionToken,
        bool isReceivingMessageFromAnotherChain,
        ReceiverChainDetails memory receiverChainDetails
    ) external returns (address) {
        if (
            CatastropheBondsCollateralPool(collateralPoolAddress)
                .getCatastropheBondsFactory() == address(0)
        ) revert CatastropheBondsFactory__FactoryNotSetInCollateralPool();

        if (s_forwarder == address(0))
            revert CatastropheBondsFactory__ForwarderNotSet();

        CatastropheBond catastropheBond = new CatastropheBond(
            collateralPoolAddress,
            catastropheCode,
            location,
            startDateTimestamp,
            endDateTimestamp,
            collateralRequiredForMintingAnyPositionToken,
            s_catastropheBonds.length
        );

        s_catastropheBonds.push(address(catastropheBond));
        if (!isReceivingMessageFromAnotherChain) {
            if (receiverChainDetails.catastropheBondsFactory == address(0))
                revert CatastropheBondsFactory__ReceiverChainDetailsCannotBeEmptyWhilePublishingMessageToAnotherChain();
            publishMessageToCreateCatastropheBondOnAnotherChain(
                catastropheCode,
                location,
                startDateTimestamp,
                endDateTimestamp,
                collateralRequiredForMintingAnyPositionToken,
                receiverChainDetails
            );
        }

        emit CatastropheBondCreated(address(catastropheBond));

        return address(catastropheBond);
    }

    function publishMessageToCreateCatastropheBondOnAnotherChain(
        string memory catastropheCode,
        string memory location,
        uint256 startDateTimestamp,
        uint256 endDateTimestamp,
        uint256 collateralRequiredForMintingAnyPositionToken,
        ReceiverChainDetails memory receiverChainDetails
    ) internal {
        bytes4 selector = this.createCatastropheBond.selector;
        bytes memory data = abi.encodeWithSelector(
            selector,
            receiverChainDetails.collateralPool,
            catastropheCode,
            location,
            startDateTimestamp,
            endDateTimestamp,
            collateralRequiredForMintingAnyPositionToken,
            true,
            ReceiverChainDetails(address(0), address(0), 0)
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverChainDetails.catastropheBondsFactory),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 3_000_000})
            ),
            feeToken: address(i_linkToken)
        });

        uint256 fee = i_routerForCCIP.getFee(
            receiverChainDetails.chainSelector,
            message
        );

        if (i_linkToken.balanceOf(address(this)) < fee) {
            revert CatastropheBondsFactory__NotFundedWithEnoughLINK(fee);
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

    /*

    CHAINLINK FUNCTIONS

    */

    function sendRequest(
        address catastropheBondAddress
    ) public onlyOwnerOrForwarder returns (bytes32 requestId) {
        if (msg.sender != i_owner) {
            if (
                s_catastropheBondAddressToRequestId[catastropheBondAddress] !=
                bytes32(0)
            ) revert CatastropheBondsFactory__RequestNotYetFulfilled();
        }

        CatastropheBond catastropheBond = CatastropheBond(
            catastropheBondAddress
        );
        string[] memory args = new string[](4);
        args[0] = catastropheBond.getCatastropheCode();
        args[1] = catastropheBond.getLocation();
        args[2] = catastropheBond.getStartDate_Timestamp().toString();
        args[3] = catastropheBond.getEndDate_Timestamp().toString();

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(
            FunctionsSource.getCatBondsApiInteractionScript()
        ); // Initialize the request with JS code

        req.addSecretsReference(
            NetworkConfig.getEncryptedSecretsUrlForChainlinkFunctions(
                block.chainid
            )
        );
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        requestId = _sendRequest(
            req.encodeCBOR(),
            NetworkConfig.getSubscriptionIdForChainlinkFunctions(block.chainid),
            300_000,
            NetworkConfig.getDONIdForChainlinkFunctions(block.chainid)
        );

        s_requestIdToCatastropheBondAddress[requestId] = catastropheBondAddress;
        s_catastropheBondAddressToRequestId[catastropheBondAddress] = requestId;

        return requestId;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        uint256 settleTo = abi.decode(response, (uint256));

        address catastropheBondAddress = s_requestIdToCatastropheBondAddress[
            requestId
        ];

        CatastropheBond catastropheBond = CatastropheBond(
            catastropheBondAddress
        );

        catastropheBond.settleTo(settleTo);

        s_catastropheBondAddressToRequestId[catastropheBondAddress] = bytes32(
            0
        );

        if (
            settleTo == uint256(CatastropheBond.SettledTo.CAP) &&
            catastropheBond.isShortPositionTokenMintedOnAnotherChain() &&
            catastropheBond.getLongPositionTokenHolder() != address(0)
        )
            catastropheBond
                .setMessageIdForPublishingMessageToBringUsdcCollateralFromAnotherChain(
                    CatastropheBondsCollateralPool(
                        catastropheBond.getCollateralPoolAddress()
                    ).publishMessageToBringUsdcCollateralFromAnotherChain(
                            catastropheBondAddress,
                            PositionToken.Position.Short
                        )
                );
        else if (
            settleTo == uint256(CatastropheBond.SettledTo.FLOOR) &&
            catastropheBond.isLongPositionTokenMintedOnAnotherChain() &&
            catastropheBond.getShortPositionTokenHolder() != address(0)
        )
            catastropheBond
                .setMessageIdForPublishingMessageToBringUsdcCollateralFromAnotherChain(
                    CatastropheBondsCollateralPool(
                        catastropheBond.getCollateralPoolAddress()
                    ).publishMessageToBringUsdcCollateralFromAnotherChain(
                            catastropheBondAddress,
                            PositionToken.Position.Long
                        )
                );

        emit Response(requestId, catastropheBondAddress, response, err);
    }

    /*
    AUTOMATION

    To Automate the sending of request to Chainlink Functions (wrt which CatastropheBond contract)
    */
    function checkUpkeep(
        bytes memory /* checkdata */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // First pass: Count eligible catastropheBonds
        uint256 count;
        for (uint256 i = 0; i < s_catastropheBonds.length; i++) {
            CatastropheBond catastropheBond = CatastropheBond(
                s_catastropheBonds[i]
            );
            if (catastropheBond.isSettled()) continue;
            else if (
                (block.timestamp >
                    (catastropheBond.getEndDate_Timestamp() +
                        (15 * SECONDS_IN_ONE_DAY))) &&
                (catastropheBond.getTotalLongTokens() == 1 ether &&
                    catastropheBond.getTotalShortTokens() == 1 ether) &&
                s_catastropheBondAddressToRequestId[s_catastropheBonds[i]] ==
                bytes32(0)
            ) {
                count++;
            }
        }

        // Second pass: Populate the eligible catastropheBonds array
        address[] memory catastropheBonds_eligibleToSettle = new address[](
            count
        );
        uint256 index;
        for (uint256 i = 0; i < s_catastropheBonds.length; i++) {
            CatastropheBond catastropheBond = CatastropheBond(
                s_catastropheBonds[i]
            );
            if (catastropheBond.isSettled()) continue;
            else if (
                (block.timestamp >
                    (catastropheBond.getEndDate_Timestamp() +
                        (15 * SECONDS_IN_ONE_DAY))) &&
                (catastropheBond.getTotalLongTokens() == 1 ether &&
                    catastropheBond.getTotalShortTokens() == 1 ether) &&
                s_catastropheBondAddressToRequestId[s_catastropheBonds[i]] ==
                bytes32(0)
            ) {
                catastropheBonds_eligibleToSettle[index] = s_catastropheBonds[
                    i
                ];
                index++;
            }
        }

        if (catastropheBonds_eligibleToSettle.length > 0) {
            upkeepNeeded = true;
            performData = abi.encode(catastropheBonds_eligibleToSettle);
        }
        return (upkeepNeeded, performData);
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        address[] memory catastropheBonds_eligibleToSettle;

        (bool upkeepNeeded, bytes memory performData) = checkUpkeep("");

        if (performData.length > 0)
            catastropheBonds_eligibleToSettle = abi.decode(
                performData,
                (address[])
            );

        if (upkeepNeeded) {
            for (
                uint256 i = 0;
                i < catastropheBonds_eligibleToSettle.length;
                i++
            ) {
                sendRequest(catastropheBonds_eligibleToSettle[i]);
                // s_numberOfUpkeepCalls += 1;
            }
        }
    }

    /*
    GETTERS
    */

    function getCollateralPoolAddress() external view returns (address) {
        return i_collateralPoolAddress;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getForwarder() external view returns (address) {
        return s_forwarder;
    }

    function getAllCatastropheBonds() external view returns (address[] memory) {
        return s_catastropheBonds;
    }

    function getCatastropheBondAtIndex(
        uint256 index
    ) external view returns (address) {
        return s_catastropheBonds[index];
    }

    /* SETTERS */
    function setForwarder(address forwarder) external onlyOwner {
        s_forwarder = forwarder;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert CatastropheBondsFactory__NotOwner();
        }
        _;
    }

    modifier onlyOwnerOrForwarder() {
        if (msg.sender != i_owner && msg.sender != s_forwarder) {
            revert CatastropheBondsFactory__NeitherOwnerNorForwarder();
        }
        _;
    }
}
