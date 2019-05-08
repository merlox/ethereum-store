pragma solidity 0.5.0;

contract Dispute {
    struct Dispute {
        uint256 id;
        uint256 orderId;
        uint256 createdAt;
        address refundReceiver;
        string reason;
        string counterReason;
        bytes32 state; // Either pending, countered or resolved. Where pending indicates "waiting for the seller to respond", countered means "the seller has responded" and resolved is "the dispute has been resolved"
    }
    // Dispute id => dispute struct
    mapping(uint256 => Dispute) public disputeById;
    Dispute[] public disputes;
    
    /// @notice To dispute an order for the specified reason as a buyer
    /// @param _id The order id to dispute
    /// @param _reason The string indicating why the buyer is disputing this order
    function disputeOrder(uint256 _id, string memory _reason) public {
        require(bytes(_reason).length > 0, 'The reason for disputing the order cannot be empty');
        Order memory order = orderById[_id];
        uint256 ein = IdentityRegistryInterface(identityRegistry).getEIN(msg.sender);
        require(order.buyer == ein, 'Only the buyer can dispute his order');
        uint256 disputeId = disputes.length;
        Dispute memory d = Dispute(disputeId, _id, now, msg.sender, _reason, '', 'pending');
        disputes.push(d);
        disputeById[disputeId] = d;
        emit DisputeGenerated(disputeId, _id, _reason);
    }

    /// @notice To respond to a dispute as a seller
    /// @param _disputeId The id of the dispute to respond to
    /// @param _counterReason The reason for countering the argument of the buyer
    function counterDispute(uint256 _disputeId, string memory _counterReason) public {
        require(bytes(_counterReason).length > 0, 'The counter reason must be set');
        Dispute memory d = disputeById[_disputeId];
        Order memory order = orderById[d.orderId];
        Product memory product = productById[order.productId];
        uint256 ein = IdentityRegistryInterface(identityRegistry).getEIN(msg.sender);
        require(product.einOwner == ein, 'Only the seller can counter dispute this order');
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
    function resolveDispute(uint256 _disputeId, bool _isBuyerWinner) public onlyOperator {
        Dispute memory d = disputeById[_disputeId];
        Order memory order = orderById[d.orderId];
        Product memory product = productById[order.productId];
        if(_isBuyerWinner) {
            // Pay the product price to the buyer as a refund
            HydroTokenTestnetInterface(token).transferFrom(product.owner, order.addressBuyer, product.price);
        }
    }
}
