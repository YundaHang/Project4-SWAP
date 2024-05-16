// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract TwoPartySwap {

    /**
    The Swap struct keeps track of participants and swap details
     */
    struct Swap {
        // assetEscrower: who escrows the asset (Alice in diagram)
        address payable assetEscrower;
        // premiumEscrower: who escrows the premium (Bob in diagram)
        address payable premiumEscrower;
        // hashLock: the hash of a secret, which only the assetEscrower knows
        bytes32 hashLock;
        // assetAddress: the ERC20 Token's address, which will be used to access accounts
        address assetAddress;
    }

    /**
    The Asset struct keeps track of the escrowed Asset
     */
    struct Asset {
        // expected: the agreed-upon amount to be escrowed
        uint expected;
        // current: the current amount of the asset that is escrowed in the swap.
        uint current;
        // deadline: the time before which the person escrowing their asset must do so
        uint deadline;
        // timeout: the maximum time the protocol can take, which assumes everything
        // goes to plan.
        uint timeout;
    }

    /**
    The Premium struct keeps track of the escrowed premium.
     */
    struct Premium {
        // expected: the agreed-upon amount to be escrowed as a premium
        uint expected;
        // current: the current amount of the premium that is escrowed in the swap
        uint current;
        // deadline: the time before which the person escrowing their premium must do so
        uint deadline;
    }

    /**
    Mappings that store our swap details. This contract stores multiple swaps; you can access
    information about a specific swap by using its hashLock as the key to the appropriate mapping.
     */
    mapping(bytes32 => Swap) public swaps;
    mapping(bytes32 => Asset) public assets;
    mapping(bytes32 => Premium) public premiums;

    /**
    SetUp: this event should emit when a swap is successfully setup.
     */
    event SetUp(
        address payable assetEscrower,
        address payable premiumEscrower,
        uint expectedPremium,
        uint expectedAsset,
        uint startTime,
        uint premiumDeadline,
        uint assetDeadline,
        uint assetTimeout
    );

    /**
    PremiumEscrowed: this event should emit when the premiumEscrower successfully escrows the premium
     */
    event PremiumEscrowed (
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    AssetEscrowed: this event should emit  when the assetEscrower successfully escrows the asset
     */
    event AssetEscrowed (
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    AssetRedeemed: this event should emit when the assetEscrower successfully escrows the asset
     */
    event AssetRedeemed(
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    PremiumRefunded: this event should emit when the premiumEscrower successfully gets their premium refunded
     */
    event PremiumRefunded(
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    PremiumRedeemed: this event should emit when the counterparty breaks the protocol
    and the assetEscrower redeems the  premium for breaking the protocol 
     */
    event PremiumRedeemed(
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    AssetRefunded: this event should emit when the counterparty breaks the protocol 
    and the assetEscrower succesffully gets their asset refunded
     */
    event AssetRefunded(
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    TODO: using modifiers for your require statements is best practice,
    but we do not require you to do so
    */ 
    modifier canSetup(bytes32 hashLock) {
        _;
    }

    modifier canEscrowPremium(bytes32 hashLock) {
        _;
    }
    modifier canEscrowAsset(bytes32 hashLock) {
        _;
    }

    modifier canRedeemAsset(bytes32 preimage, bytes32 hashLock) {
        _;
    }

    modifier canRefundAsset(bytes32 hashLock) {
        _;
    }

    modifier canRefundPremium(bytes32 hashLock) {
        _;
    }

    modifier canRedeemPremium(bytes32 hashLock) {
        _;
    }
   
    /**
    setup is called to initialize an instance of a swap in this contract. 
    Due to storage constraints, the various parts of the swap are spread 
    out between the three different mappings above: swaps, assets, 
    and premiums.
    */
    function setup(
        uint expectedAssetEscrow,
        uint expectedPremiumEscrow,
        address payable assetEscrower,
        address payable premiumEscrower,
        address assetAddress,
        bytes32 hashLock,
        uint startTime,
        bool firstAssetEscrow,
        uint delta
    )
        public 
        payable 
        canSetup(hashLock) 
    {
        //TODO
        require(swaps[hashLock].assetEscrower == address(0), "Duplicate swaps");
        require(swaps[hashLock].premiumEscrower == address(0), "Duplicate swaps");
    
        Swap storage newSwap = swaps[hashLock];
        newSwap.assetAddress = assetEscrower;
        newSwap.premiumEscrower = premiumEscrower;
        newSwap.hashLock = hashLock;
        newSwap.assetAddress = assetAddress;

        Asset storage newAsset = assets[hashLock];
        newAsset.expected = expectedAssetEscrow;
        newAsset.current = 0;
        if (firstAssetEscrow) {
            newAsset.deadline = startTime + 3 * delta;
            newAsset.timeout = startTime + 6 * delta;
        } else {
            newAsset.deadline = startTime + 4 * delta;
            newAsset.timeout = startTime + 5 * delta;
        }

        Premium storage newPremium = premiums[hashLock];
        newPremium.expected = expectedPremiumEscrow;
        newPremium.current = 0;
        if (firstAssetEscrow) {
            newPremium.deadline = startTime + 2 * delta;
        } else {
            newPremium.deadline = startTime + 1 * delta;
        }

        emit SetUp(
            assetEscrower,
            premiumEscrower,
            newPremium.expected,
            newAsset.expected,
            startTime,
            newPremium.deadline,
            newAsset.deadline,
            newAsset.timeout
        );

    }

    /**
    The premium escrower has to escrow their premium for the protocol to succeed.
    */
    function escrowPremium(bytes32 hashLock)
        public
        payable
        canEscrowPremium(hashLock)
    {
        //TODO
        require(block.timestamp <= premiums[hashLock].deadline, "Deadline has passed");
        require(msg.sender == swaps[hashLock].premiumEscrower, "Caller is not the premium escrower");
        require(premiums[hashLock].current == 0, "Premium has already been escrowed");
        require(ERC20(swaps[hashLock].assetAddress).balanceOf(msg.sender) >= premiums[hashLock].expected, "Not enough balance");
 
        premiums[hashLock].current += premiums[hashLock].expected;
        ERC20(swaps[hashLock].assetAddress).transferFrom(msg.sender, address(this), premiums[hashLock].expected);
 
        emit PremiumEscrowed(
            msg.sender,
            premiums[hashLock].expected,
            msg.sender,
            address(this),
            premiums[hashLock].current,
            assets[hashLock].current
        );
    }

    /**
    The asset escrower has to escrow their premium for the protocol to succeed
    */
    function escrowAsset(bytes32 hashLock) 
        public 
        payable 
        canEscrowAsset(hashLock) 
    {
        //TODO
        require(block.timestamp <= assets[hashLock].deadline, "Deadline has passed");
        require(premiums[hashLock].current != 0, "Premium is not escrowed before asset");
        require(assets[hashLock].current == 0, "Assets escrowed more than once");
        require(ERC20(swaps[hashLock].assetAddress).balanceOf(msg.sender) >= assets[hashLock].expected, "Not enough balance");
 
        assets[hashLock].current += assets[hashLock].expected;
        ERC20(swaps[hashLock].assetAddress).transferFrom(msg.sender, address(this), assets[hashLock].expected);
 
        emit AssetEscrowed(
            msg.sender,
            assets[hashLock].expected,
            msg.sender,
            address(this),
            premiums[hashLock].current,
            assets[hashLock].current
        );
    }

    /**
    redeemAsset redeems the asset for the new owner
    */
    function redeemAsset(bytes32 preimage, bytes32 hashLock) 
        public 
        canRedeemAsset(preimage, hashLock) 
    {
        //TODO
        require(block.timestamp <= assets[hashLock].timeout, "Deadline has passed");
        require(msg.sender == swaps[hashLock].premiumEscrower, "Not proper sendder");
        require(sha256(abi.encode(preimage)) == hashLock, "Preimage does not hash to hashLock");
        require(assets[hashLock].current > 0, "Asset not escrowed");

        ERC20(swaps[hashLock].assetAddress).transfer(msg.sender, assets[hashLock].current);

        emit AssetRedeemed(
            msg.sender,
            assets[hashLock].current,
            address(this),
            msg.sender,
            premiums[hashLock].current,
            0
        );

        assets[hashLock].current = 0;
    }

    /**
    refundPremium refunds the premiumEscrower's premium should the swap succeed
    */
    function refundPremium(bytes32 hashLock) 
        public 
        canRefundPremium(hashLock)
    {
        //TODO
        require(premiums[hashLock].current > 0, "Premium not escrowed");
        require(assets[hashLock].current == 0, "Asset already escrowed");
        require(block.timestamp > premiums[hashLock].deadline, "Too early to refund premium");

        ERC20(swaps[hashLock].assetAddress).transfer(swaps[hashLock].premiumEscrower, premiums[hashLock].current);

        emit PremiumRefunded(
            msg.sender,
            premiums[hashLock].current,
            address(this),
            msg.sender,
            0,
            assets[hashLock].current
        );
    }

    /**
    refundAsset refunds the asset to its original owner should the swap fail
    */
    function refundAsset(bytes32 hashLock) 
        public 
        canRefundAsset(hashLock) 
    {
       //TODO
       require(block.timestamp > assets[hashLock].deadline, "Too early to refund asset");
       require(assets[hashLock].current > 0, "Asset not escrowed");

       ERC20(swaps[hashLock].assetAddress).transfer(msg.sender, assets[hashLock].current);

       emit AssetRefunded(
            msg.sender,
            assets[hashLock].current,
            address(this),
            msg.sender,
            premiums[hashLock].current,
            0
       );
    }

    /**
    redeemPremium allows a party to redeem the counterparty's premium should the swap fail
    */
    function redeemPremium(bytes32 hashLock) 
        public 
        canRedeemPremium(hashLock)
    {
        //TODO
        require(premiums[hashLock].current > 0, "Premium is not escrowed");
        require(premiums[hashLock].expected == premiums[hashLock].current, "Expected premium does not match current");
        require(assets[hashLock].expected > 0, "Expected asset amount is 0");
        require(block.timestamp > premiums[hashLock].deadline, "Too early to redeem premium");

        ERC20(swaps[hashLock].assetAddress).transfer(msg.sender, premiums[hashLock].current);

        emit PremiumRedeemed(
            msg.sender,
            premiums[hashLock].current,
            address(this),
            msg.sender,
            0,
            assets[hashLock].current
        );

        premiums[hashLock].current = 0;
    }
}
