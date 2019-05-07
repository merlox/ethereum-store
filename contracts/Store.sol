pragma solidity ^0.5.4;

contract HydroTokenTestnetInterface {
    function transfer(address _to, uint256 _amount) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success);
    function doTransfer(address _from, address _to, uint _amount) internal;
    function balanceOf(address _owner) public view returns (uint256 balance);
    function approve(address _spender, uint256 _amount) public returns (bool success);
    function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success);
    function burn(uint256 _value) public;
    function allowance(address _owner, address _spender) public view returns (uint256 remaining);
    function totalSupply() public view returns (uint);
    function setRaindropAddress(address _raindrop) public;
    function authenticate(uint _value, uint _challenge, uint _partnerId) public;
    function setBalances(address[] memory _addressList, uint[] memory _amounts) public;
    function getMoreTokens() public;
}

interface IdentityRegistryInterface {
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        external pure returns (bool);

    // Identity View Functions /////////////////////////////////////////////////////////////////////////////////////////
    function identityExists(uint ein) external view returns (bool);
    function hasIdentity(address _address) external view returns (bool);
    function getEIN(address _address) external view returns (uint ein);
    function isAssociatedAddressFor(uint ein, address _address) external view returns (bool);
    function isProviderFor(uint ein, address provider) external view returns (bool);
    function isResolverFor(uint ein, address resolver) external view returns (bool);
    function getIdentity(uint ein) external view returns (
        address recoveryAddress,
        address[] memory associatedAddresses, address[] memory providers, address[] memory resolvers
    );

    // Identity Management Functions ///////////////////////////////////////////////////////////////////////////////////
    function createIdentity(address recoveryAddress, address[] calldata providers, address[] calldata resolvers)
        external returns (uint ein);
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] calldata providers, address[] calldata resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint ein);
    function addAssociatedAddress(
        address approvingAddress, address addressToAdd, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function addAssociatedAddressDelegated(
        address approvingAddress, address addressToAdd,
        uint8[2] calldata v, bytes32[2] calldata r, bytes32[2] calldata s, uint[2] calldata timestamp
    ) external;
    function removeAssociatedAddress() external;
    function removeAssociatedAddressDelegated(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        external;
    function addProviders(address[] calldata providers) external;
    function addProvidersFor(uint ein, address[] calldata providers) external;
    function removeProviders(address[] calldata providers) external;
    function removeProvidersFor(uint ein, address[] calldata providers) external;
    function addResolvers(address[] calldata resolvers) external;
    function addResolversFor(uint ein, address[] calldata resolvers) external;
    function removeResolvers(address[] calldata resolvers) external;
    function removeResolversFor(uint ein, address[] calldata resolvers) external;

    // Recovery Management Functions ///////////////////////////////////////////////////////////////////////////////////
    function triggerRecoveryAddressChange(address newRecoveryAddress) external;
    function triggerRecoveryAddressChangeFor(uint ein, address newRecoveryAddress) external;
    function triggerRecovery(uint ein, address newAssociatedAddress, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        external;
    function triggerDestruction(
        uint ein, address[] calldata firstChunk, address[] calldata lastChunk, bool resetResolvers
    ) external;
}

contract Store {
    event DisputeGenerated(uint256 indexed id, uint256 indexed orderId, string reason);

    struct Product {
        uint256 id;
        bytes32 sku;
        string title;
        string description;
        uint256 date;
        uint256 einOwner; // EIN owner
        address owner;
        uint256 price;
        string image;
        bytes32[] attributes;
        bytes32[] attributeValues;
        uint256 quantity;
    }
    struct Order {
        uint256 id; // Unique order ID
        uint256 addressId;
        uint256 productId;
        uint256 date;
        uint256 buyer; // EIN buyer
        address addressBuyer;
        string state; // Either 'pending', 'completed'
        uint256 barcode;
    }
    struct Address {
        string nameSurname;
        string direction;
        bytes32 city;
        bytes32 stateRegion;
        uint256 postalCode;
        bytes32 country;
        uint256 phone;
    }
    struct Inventory {
        uint256 id;
        string name;
        bytes32[] skus;
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
    // Product id => product
    mapping(uint256 => Product) public productById;
    // Order id => order struct
    mapping(uint256 => Order) public orderById;
    // Dispute id => dispute struct
    mapping(uint256 => Dispute) public disputeById;
    // Id => address
    mapping(uint256 => Address) public addressById;
    Product[] public products;
    Inventory[] public inventories;
    Dispute[] public disputes;
    address[] public operators;
    address public owner;
    uint256 public lastId;
    uint256 public lastOrderId;
    uint256 public lastAddressId;
    address public token;
    address public identityRegistry;

    modifier onlyOperator {
        require(operatorExists(msg.sender), 'Only a valid operator can run this function');
        _;
    }

    /// @notice To setup the address of the ERC-721 token to use for this contract
    /// @param _token The token address
    constructor(address _token, address _identityRegistry) public {
        owner = msg.sender;
        token = _token;
        identityRegistry = _identityRegistry;
    }

    /// @notice To publish a product as a seller
    /// @param _title The title of the product
    /// @param _description The description of the product
    /// @param _price The price of the product in ETH
    /// @param _image The image URL of the product
    function publishProduct(string memory _title, bytes32 _sku, string memory _description, uint256 _price, string memory _image, bytes32[] memory _attributes, bytes32[] memory _attributeValues, uint256 _quantity) public {
        require(bytes(_title).length > 0, 'The title cannot be empty');
        require(bytes(_description).length > 0, 'The description cannot be empty');
        require(_price > 0, 'The price cannot be empty');
        require(bytes(_image).length > 0, 'The image cannot be empty');
        require(IdentityRegistryInterface(identityRegistry).hasIdentity(msg.sender), 'You must have an EIN associated with your Ethereum account to add a product');

        Product memory p = Product(lastId, _sku, _title, _description, now, IdentityRegistryInterface(identityRegistry).getEIN(msg.sender), msg.sender, _price, _image, _attributes, _attributeValues, _quantity);
        products.push(p);
        productById[lastId] = p;
        lastId++;
    }

    /// @notice To create an inventory in which to store product skus
    /// @param _name The name of the inventory
    /// @param _skus The array of skus to add to the inventory
    function createInventory(string memory _name, bytes32[] memory _skus) public {
        require(bytes(_name).length > 0, 'The name must be set');
        require(_skus.length > 0, 'There must be at least one sku for this inventory');
        Inventory memory inv = Inventory(inventories.length, _name, _skus);
        inventories.push(inv);
    }

    /// @notice To delete an inventory by id
    /// @param _id The id of the inventory to delete
    function deleteInventory(uint256 _id) public {
        // Delete the inventory from the array of inventories
        for(uint256 i = 0; i < inventories.length; i++) {
            if(inventories[i].id == _id) {
                Inventory memory lastElement = inventories[inventories.length - 1];
                inventories[i] = lastElement;
                inventories.length--;
            }
        }
    }

    /// @notice To buy a new product, note that the seller must authorize this contract to manage the token
    /// @param _id The id of the product to buy
    /// @param _nameSurname The name and surname of the buyer
    /// @param _lineOneDirection The first line for the user address
    /// @param _lineTwoDirection The second, optional user address line
    /// @param _city Buyer's city
    /// @param _stateRegion The state or region where the buyer lives
    /// @param _postalCode The postal code of his location
    /// @param _country Buyer's country
    /// @param _phone The optional phone number for the shipping company
    /// The payment in HYDRO is made automatically by making a transferFrom after approving the right amount of tokens using the product price
    function buyProduct(uint256 _id, string memory _nameSurname, string memory _direction, bytes32 _city, bytes32 _stateRegion, uint256 _postalCode, bytes32 _country, uint256 _phone, uint256 _barcode) public {
        // The line 2 address and phone are optional, the rest are mandatory
        require(bytes(_nameSurname).length > 0, 'The name and surname must be set');
        require(bytes(_direction).length > 0, 'The line one direction must be set');
        require(_city.length > 0, 'The city must be set');
        require(_stateRegion.length > 0, 'The state or region must be set');
        require(_postalCode > 0, 'The postal code must be set');
        require(_country > 0, 'The country must be set');
        require(IdentityRegistryInterface(identityRegistry).hasIdentity(msg.sender), 'You must have an EIN associated with your Ethereum account to purchase the product');

        uint256 ein = IdentityRegistryInterface(identityRegistry).getEIN(msg.sender);
        Product memory p = productById[_id];
        require(bytes(p.title).length > 0, 'The product must exist to be purchased');
        require(HydroTokenTestnetInterface(token).allowance(msg.sender, address(this)) >= p.price, 'You must have enough HYDRO tokens approved to purchase this product');
        Address memory newAddress = Address(_nameSurname, _direction, _city, _stateRegion, _postalCode, _country, _phone);
        Order memory newOrder = Order(lastOrderId, lastAddressId, _id, now, ein, msg.sender, 'pending', _barcode);

        // Update the quantity of remaining products
        if(p.quantity > 0) {
            p.quantity--;
            productById[_id] = p;
        }

        pendingOrders[ein].push(newOrder);
        orderById[_id] = newOrder;
        addressById[lastAddressId] = newAddress;
        HydroTokenTestnetInterface(token).transferFrom(msg.sender, p.owner, p.price); // Pay the product price to the seller
        lastOrderId++;
        lastAddressId++;
    }

    /// @notice To mark an order as completed
    /// @param _id The id of the order to mark as sent and completed
    function markOrderCompleted(uint256 _id) public {
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

    /// @notice To delete a product
    /// @param _id The id of the product to delete
    function deleteProduct(uint256 _id) public {
        require(IdentityRegistryInterface(identityRegistry).hasIdentity(msg.sender), 'You must have an EIN associated with your Ethereum account to delete a product');
        uint256 ein = IdentityRegistryInterface(identityRegistry).getEIN(msg.sender);
        require(productById[_id].einOwner == ein, 'You must be the owner to delete the product');
        delete productById[_id];
        // Delete the product from the array of products since we only want to purchase one product per order
        for(uint256 i = 0; i < products.length; i++) {
            if(products[i].id == _id) {
                Product memory lastElement = products[products.length - 1];
                products[i] = lastElement;
                products.length--;
            }
        }
    }

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

    /// @notice To add or delete operators by the owner
    /// @param _user A valid address to add or remove from the list of operators
    /// @param _isRemoved Whether you want to add or remove this operator
    function setOperator(address _user, bool _isRemoved) public {
        require(msg.sender == owner, 'Only the owner can add operators');
        if(_isRemoved) {
            for(uint256 i = 0; i < operators.length; i++) {
                if(operators[i] == _user) {
                    address lastElement = operators[operators.length - 1];
                    operators[i] = lastElement;
                    operators.length--;
                }
            }
        } else {
            operators.push(_user);
        }
    }

    /// @notice Returns the product length
    /// @return uint256 The number of products
    function getProductsLength() public view returns(uint256) {
        return products.length;
    }

    /// @notice To get the pending seller or buyer orders
    /// @param _type If you want to get the pending seller, buyer or completed orders
    /// @param _einOwner The EIN of the owner of those orders
    /// @return uint256 The number of orders to get
    function getOrdersLength(bytes32 _type, uint256 _einOwner) public view returns(uint256) {
        if(_type == 'pending') return pendingOrders[_einOwner].length;
        else if(_type == 'completed') return completedOrders[_einOwner].length;
    }

    /// @notice To check if an operator exists
    /// @param _operator The address of the operator to check
    /// @return bool Whether he's a valid operator or not
    function operatorExists(address _operator) internal view returns(bool) {
        for(uint256 i = 0; i < operators.length; i++) {
            if(_operator == operators[i]) {
                return true;
            }
        }
        return false;
    }
}
