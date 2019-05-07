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

    /// @notice To mark an order as completed
    /// @param _id The id of the order to mark as sent and completed
    function markOrderCompletedStorage(uint256 _id) public {
        Order memory order = orderById[_id];
        Product memory product = productById[order.productId];
        require(IdentityRegistryInterface(identityRegistry).hasIdentity(msg.sender), 'You must have an EIN associated with your Ethereum account to mark the order as completed');
        uint256 ein = IdentityRegistryInterface(identityRegistry).getEIN(msg.sender);
        require(product.einOwner == ein, 'Only the seller can mark the order as completed');
        order.state = 'completed';

        // Delete the seller order from the array of pending orders
        for(uint256 i = 0; i < pendingOrders[product.einOwner].length; i++) {
            if(pendingOrders[product.einOwner][i].id == _id) {
                Order memory lastElement = orderById[pendingOrders[product.einOwner].length - 1];
                pendingOrders[product.einOwner][i] = lastElement;
                pendingOrders[product.einOwner].length--;
            }
        }

        completedOrders[order.buyer].push(order);
        orderById[_id] = order;
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

    /// @notice To resolve a dispute and pay the buyer from the seller's approved balance
    /// @param _disputeId The id of the dispute to resolve
    /// @param _isBuyerWinner If the winner is the buyer or not to perform the transfer
    function resolveDisputeStorage(uint256 _disputeId, address _token, address _productOwner, uint256 _productPrice, bool _isBuyerWinner) internal {
        Dispute memory d = disputeById[_disputeId];
        Order memory order = orderById[d.orderId];

        if(_isBuyerWinner) {
            // Pay the product price to the buyer as a refund
            HydroTokenTestnetInterface(_token).transferFrom(_productOwner, order.addressBuyer, _productPrice);
        }
    }

    function getProductIdStorage(uint256 _disputeId) internal view returns(uint256) {
        Dispute memory d = disputeById[_disputeId];
        Order memory order = orderById[d.orderId];
        return order.productId;
    }

    /// @notice To get the pending seller or buyer orders
    /// @param _type If you want to get the pending seller, buyer or completed orders
    /// @param _einOwner The EIN of the owner of those orders
    /// @return uint256 The number of orders to get
    function getOrdersLengthStorage(bytes32 _type, uint256 _einOwner) public view returns(uint256) {
        if(_type == 'pending') return pendingOrders[_einOwner].length;
        else if(_type == 'completed') return completedOrders[_einOwner].length;
    }
}
