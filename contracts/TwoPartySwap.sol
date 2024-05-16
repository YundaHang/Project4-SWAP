// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract TwoPartySwap {

    using SafeERC20 for IERC20;

    struct Swap {
        address payable assetEscrower;
        address payable premiumEscrower;
        bytes32 hashLock;
        address assetAddress;
    }

    struct Asset {
        uint expected;
        uint current;
        uint deadline;
        uint timeout;
    }

    struct Premium {
        uint expected;
        uint current;
        uint deadline;
    }

    mapping(bytes32 => Swap) public swaps;
    mapping(bytes32 => Asset) public assets;
    mapping(bytes32 => Premium) public premiums;

    event SetUp(
        address payable assetEscrower,
        address payable premiumEscrower,
        uint expectedPremium,
        uint expectedAsset,
        uint startTime,
        uint premiumDeadline,
        uint assetDeadline,
        uint assetTimeout,
        bool firstAssetEscrow
    );

    event PremiumEscrowed (
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    event AssetEscrowed (
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    event AssetRedeemed(
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    event PremiumRefunded(
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    event PremiumRedeemed(
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    event AssetRefunded(
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    modifier canSetup(bytes32 hashLock) {
        require(swaps[hashLock].assetEscrower == address(0), "Swap already set up");
        _;
    }

    modifier canEscrowPremium(bytes32 hashLock) {
        require(swaps[hashLock].assetEscrower != address(0), "Swap not set up");
        require(premiums[hashLock].current == 0, "Premium already escrowed");
        require(msg.sender == swaps[hashLock].premiumEscrower, "Only premium escrower can escrow premium");
        _;
    }

    modifier canEscrowAsset(bytes32 hashLock) {
        require(swaps[hashLock].assetEscrower != address(0), "Swap not set up");
        require(assets[hashLock].current == 0, "Asset already escrowed");
        require(premiums[hashLock].current > 0, "Premium not escrowed before asset");
        require(msg.sender == swaps[hashLock].assetEscrower, "Only asset escrower can escrow asset");
        _;
    }

    modifier canRedeemAsset(bytes32 preimage, bytes32 hashLock) {
        require(keccak256(abi.encodePacked(preimage)) == hashLock, "Invalid preimage");
        require(assets[hashLock].current > 0, "No asset escrowed");
        require(msg.sender == swaps[hashLock].assetEscrower, "Only asset escrower can redeem asset");
        require(block.timestamp < assets[hashLock].timeout, "Timeout reached");
        _;
    }

    modifier canRefundAsset(bytes32 hashLock) {
        require(swaps[hashLock].assetEscrower != address(0), "Swap not set up");
        require(assets[hashLock].current > 0, "No asset escrowed");
        require(block.timestamp > assets[hashLock].deadline, "Deadline not reached");
        _;
    }

    modifier canRefundPremium(bytes32 hashLock) {
        require(swaps[hashLock].assetEscrower != address(0), "Swap not set up");
        require(premiums[hashLock].current > 0, "No premium escrowed");
        require(block.timestamp > premiums[hashLock].deadline, "Deadline not reached");
        _;
    }

    modifier canRedeemPremium(bytes32 hashLock) {
        require(swaps[hashLock].assetEscrower != address(0), "Swap not set up");
        require(premiums[hashLock].current > 0, "No premium escrowed");
        require(block.timestamp > assets[hashLock].timeout, "Timeout not reached");
        require(premiums[hashLock].expected == premiums[hashLock].current, "Expected premium does not match current");
        _;
    }

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
        swaps[hashLock] = Swap({
            assetEscrower: assetEscrower,
            premiumEscrower: premiumEscrower,
            hashLock: hashLock,
            assetAddress: assetAddress
        });

        uint assetDeadline;
        if (firstAssetEscrow) {
            assetDeadline = startTime + delta;
        } else {
            assetDeadline = startTime + 2 * delta;
        }

        uint premiumDeadline = startTime + delta;

        assets[hashLock] = Asset({
            expected: expectedAssetEscrow,
            current: 0,
            deadline: assetDeadline,
            timeout: startTime + 2 * delta
        });

        premiums[hashLock] = Premium({
            expected: expectedPremiumEscrow,
            current: 0,
            deadline: premiumDeadline
        });

        emit SetUp(
            assetEscrower,
            premiumEscrower,
            expectedPremiumEscrow,
            expectedAssetEscrow,
            startTime,
            premiumDeadline,
            assetDeadline,
            startTime + 2 * delta,
            firstAssetEscrow
        );
    }

    function escrowPremium(bytes32 hashLock)
        public
        payable
        canEscrowPremium(hashLock)
    {
        require(msg.value >= premiums[hashLock].expected, "Insufficient premium");
        require(msg.sender.balance >= msg.value, "Insufficient balance");

        premiums[hashLock].current += msg.value;

        emit PremiumEscrowed(
            msg.sender,
            msg.value,
            address(0), // Transfer from null address
            swaps[hashLock].premiumEscrower,
            premiums[hashLock].current,
            assets[hashLock].current
        );

        swaps[hashLock].premiumEscrower.transfer(msg.value);
    }

    function escrowAsset(bytes32 hashLock) 
        public 
        payable 
        canEscrowAsset(hashLock) 
    {
        IERC20 assetToken = IERC20(swaps[hashLock].assetAddress);
        require(assetToken.allowance(msg.sender, address(this)) >= assets[hashLock].expected, "Insufficient allowance");
        require(assetToken.balanceOf(msg.sender) >= assets[hashLock].expected, "Insufficient balance");

        uint assetBalanceBefore = assetToken.balanceOf(address(this));

        assetToken.safeTransferFrom(msg.sender, address(this), assets[hashLock].expected);

        uint assetBalanceAfter = assetToken.balanceOf(address(this));
        uint assetTransferred = assetBalanceAfter - assetBalanceBefore;

        require(assetTransferred == assets[hashLock].expected, "Incorrect amount of asset transferred");

        assets[hashLock].current += assetTransferred;

        emit AssetEscrowed(
            msg.sender,
            assetTransferred,
            msg.sender,
            address(this),
            premiums[hashLock].current,
            assets[hashLock].current
        );
    }

    function redeemAsset(bytes32 preimage, bytes32 hashLock) 
        public 
        canRedeemAsset(preimage, hashLock) 
    {
        require(assets[hashLock].current > 0, "No asset escrowed");
        require(msg.sender == swaps[hashLock].assetEscrower, "Only asset escrower can redeem asset");
        require(block.timestamp < assets[hashLock].timeout, "Timeout reached");

        IERC20 assetToken = IERC20(swaps[hashLock].assetAddress);
        uint assetBalanceBefore = assetToken.balanceOf(swaps[hashLock].assetEscrower);

        assetToken.safeTransfer(swaps[hashLock].assetEscrower, assets[hashLock].current);

        uint assetBalanceAfter = assetToken.balanceOf(swaps[hashLock].assetEscrower);
        uint assetTransferred = assetBalanceAfter - assetBalanceBefore;

        require(assetTransferred == assets[hashLock].current, "Incorrect amount of asset redeemed");

        emit AssetRedeemed(
            msg.sender,
            assets[hashLock].current,
            address(this),
            swaps[hashLock].assetEscrower,
            premiums[hashLock].current,
            0
        );

        delete swaps[hashLock];
        delete assets[hashLock];
        delete premiums[hashLock];
    }

    function refundPremium(bytes32 hashLock) 
        public 
        canRefundPremium(hashLock)
    {
        require(block.timestamp > premiums[hashLock].deadline, "Deadline not reached");

        uint refundAmount = premiums[hashLock].current;
        premiums[hashLock].current = 0;

        (bool success, ) = swaps[hashLock].premiumEscrower.call{value: refundAmount}("");
        require(success, "Failed to send refund");

        emit PremiumRefunded(
            msg.sender,
            refundAmount,
            address(this),
            swaps[hashLock].premiumEscrower,
            0,
            assets[hashLock].current
        );

        delete swaps[hashLock];
        delete assets[hashLock];
        delete premiums[hashLock];
    }

    function refundAsset(bytes32 hashLock) 
        public 
        canRefundAsset(hashLock) 
    {
        require(block.timestamp > assets[hashLock].deadline, "Deadline not reached");

        IERC20 assetToken = IERC20(swaps[hashLock].assetAddress);
        uint refundAmount = assets[hashLock].current;
        assets[hashLock].current = 0;

        assetToken.safeTransfer(swaps[hashLock].assetEscrower, refundAmount);

        emit AssetRefunded(
            msg.sender,
            refundAmount,
            address(this),
            swaps[hashLock].assetEscrower,
            premiums[hashLock].current,
            0
        );

        delete swaps[hashLock];
        delete assets[hashLock];
        delete premiums[hashLock];
    }

    function redeemPremium(bytes32 hashLock) 
        public 
        canRedeemPremium(hashLock)
    {
        require(block.timestamp > assets[hashLock].timeout, "Timeout not reached");
        require(premiums[hashLock].expected == premiums[hashLock].current, "Expected premium does not match current");

        uint redeemAmount = premiums[hashLock].current;
        premiums[hashLock].current = 0;

        (bool success, ) = swaps[hashLock].assetEscrower.call{value: redeemAmount}("");
        require(success, "Failed to send redeem amount");

        emit PremiumRedeemed(
            msg.sender,
            redeemAmount,
            address(this),
            swaps[hashLock].premiumEscrower,
            0,
            assets[hashLock].current
        );

        delete swaps[hashLock];
        delete assets[hashLock];
        delete premiums[hashLock];
    }
}
