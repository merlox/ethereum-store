pragma solidity ^0.5.4;

/// @notice A contract to store several variables that can't be held in the store contract to avoid stack too deep errors
/// @author Merunas Grincalaitis <merunasgrincalaitis@gmail.com>
contract Storage {
    struct Order {
        uint256 id; // Product ID associated with the order
        uint256 productId;
        uint256 date;
        uint256 buyer; // EIN buyer
        address addressBuyer;
        string nameSurname;
        string lineOneDirection;
        string lineTwoDirection;
        bytes32 city;
        bytes32 stateRegion;
        uint256 postalCode;
        bytes32 country;
        uint256 phone;
        string state; // Either 'pending', 'completed'
        uint256 barcode;
    }
    struct Dispute {
        uint256 id;
        uint256 orderId;
        uint256 createdAt;
        address refundReceiver;
        string reason;
        string counterReason;
        bytes32 state; // Either pending, countered or resolved. Where pending indicates "waiting for the seller to respond", countered means "the seller has responded" and resolved is "the dispute has been resolved"
    }

    // Seller ein => orders
    mapping(uint256 => Order[]) public pendingOrders; // The products waiting to be fulfilled
    // Buyer ein => orders
    mapping(uint256 => Order[]) public completedOrders;
    // Order id => order struct
    mapping(uint256 => Order) public orderById;
    // Dispute id => dispute struct
    mapping(uint256 => Dispute) public disputeById;
    Dispute[] public disputes;
    address[] public operators;
    uint256 public lastId;
    uint256 public lastOrderId;

    function buyProductStorage(uint256 _ein, uint256 _id, string memory _nameSurname, string memory _lineOneDirection, string memory _lineTwoDirection, bytes32 _city, bytes32 _stateRegion, uint256 _postalCode, bytes32 _country, uint256 _phone, uint256 _barcode) internal {
        Order memory newOrder = Order(lastOrderId, _id, now, _ein, msg.sender, _nameSurname, _lineOneDirection, _lineTwoDirection, _city, _stateRegion, _postalCode, _country, _phone, 'pending', _barcode);

        pendingOrders[_ein].push(newOrder);
        orderById[_id] = newOrder;
        lastOrderId++;
    }

    function disputeOrderStorage(uint256 _ein, uint256 _id, string memory _reason) internal returns(uint256) {
        Order memory order = orderById[_id];
        require(order.buyer == _ein, 'Only the buyer can dispute his order');
        uint256 disputeId = disputes.length;
        Dispute memory d = Dispute(disputeId, _id, now, msg.sender, _reason, '', 'pending');
        disputes.push(d);
        disputeById[disputeId] = d;
        return disputeId;
    }

    function counterDisputeStorage(uint256 _disputeId, string memory _counterReason) internal {
        Dispute memory d = disputeById[_disputeId];
        Order memory order = orderById[d.orderId];

        d.counterReason = _counterReason;
        d.state = 'countered';
        disputeById[_disputeId] = d;
        for(uint256 i = 0; i < disputes.length; i++) {
            if(disputes[i].id == _disputeId) {
                disputes[i] = d;
                break;
            }
        }
    }

    function getProductIdStorage(uint256 _disputeId) internal view returns(uint256) {
        Dispute memory d = disputeById[_disputeId];
        Order memory order = orderById[d.orderId];
        return order.productId;
    }
}
