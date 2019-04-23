pragma solidity 0.5.0;

contract HydroGiftCardInterface {
    constructor (address _snowflakeAddress) external;

    function setSnowflakeAddress(address _snowflakeAddress) external;
    function onAddition(uint ein, uint allowance, bytes memory) external returns (bool);
    function onRemoval(uint ein, bytes memory) external returns (bool);
    function setOffers(uint[] memory _amounts) external;
    function getOffers(uint _vendorEIN) external view returns (uint[] memory);
    function refund(uint _giftCardId) external;
    function refundGiftCard(uint _giftCardId) external;
    function purchaseOffer(uint _vendorEIN, uint _value) external;
    function transferGiftCard(
        uint _giftCardId, uint _recipientEIN,
        uint8 v, bytes32 r, bytes32 s
    ) external;
    function redeem(
        uint _giftCardId, uint _amount, uint _timestamp,
        uint8 v, bytes32 r, bytes32 s
    ) external;
    function redeemAndCall(
      uint _giftCardId, uint _amount, uint _timestamp,
      uint8 v, bytes32 r, bytes32 s,
      address _vendorContractAddress, bytes memory _extraData
    ) external;
    function vendorRedeem(uint _giftCardId, uint _amount) external;
    function getGiftCardBalance(uint _giftCardId) external view returns (uint256);
    function getGiftCard(uint _id)
      external view returns(
        string memory vendorCasedHydroID,
        string memory customerCasedHydroID,
        uint balance
    );
    function getCustomerGiftCardIds() external view returns(uint[] memory giftCardIds);
    function getVendorGiftCardIds() external view returns(uint[] memory giftCardIds);

    event Debug(string);
    event Debug(uint);
    event HydroGiftCardOffersSet(uint indexed vendorEIN, uint[] amounts);
    event HydroGiftCardPurchased(uint indexed vendorEIN, uint indexed buyerEIN, uint amount);
    event HydroGiftCardRefunded(uint indexed id, uint indexed vendorEIN, uint indexed customerEIN, uint amount);
    event HydroGiftCardTransferred(uint indexed id, uint indexed buyerEIN, uint indexed recipientEIN);
    event HydroGiftCardRedeemAllowed(uint indexed id, uint indexed vendorEIN, uint indexed customerEIN, uint amount);
    event HydroGiftCardVendorRedeemed(uint indexed id, uint indexed vendorEIN, uint indexed customerEIN, uint amount);
}
