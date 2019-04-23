pragma solidity ^0.5.4;

import './HydroTokenTestnetInterface.sol';
import './IdentityRegistryInterface.sol';
import './HydroGiftCardInterface.sol';

/*
DONE Create a SKU - assign a unique ID to a product
- With ecommerce-dapp contract

DONE Define attributes - define the attributes of the product to store on-chain, such as gender, size, color, materials
- Attributes will be stored in an array of bytes32[] and the values will be bytes32[]. If it's a number, you simply convert it to string.

DONE Inventory - add a SKU to a group of other SKUs to form the foundation of inventory management
- Create an inventory struct containing products or use mappings or arrays

DONE Shipping - define shipping parameters of the SKU or inventory
- Create a shipping or order struct by using ecommerce-dapp

Price - define price of the SKU or inventory, accept gift cards and coupons from other Hydro Snowflake smart contracts
- To be determined

DONE Create Order - create an order, tied to a Snowflake ID of a business and an end-user containing date, SKU info, shipping info
- Can be done with ecommerce-dapp + IdentityRegistryInterface.identityExists(ein) +  IdentityRegistryInterface.hasIdentity(address) + IdentityRegistryInterface.getEIN(address)

DONE Create Barcode - create a unique barcode tied to an order
- Barcode js https://lindell.me/JsBarcode/

Authenticate Purchase - use Hydro Raindrop to confirm a purchase
- To be determined

DONE Authenticate Shipment - perform an authentication of the SKU(s) being sent and reduce from inventory
- Reduce the inventory in the smart contract only

Authenticate Receipt - perform an authentication of the product SKU being received by scanning the barcode and storing in the Snowflake
- to be determined

Dispute - create a flag on a Snowflake for a disputed order or shipment
- After a user has purchased a product, he has the option to call the function disputeOrder() while providing a string explaining his situation. An event will be emitted and the seller will be able to call the function counterDisputeOrder() to provide an explanation of the situation. After that, an approved operator will be able to determine how's right. The seller is expected to provide the shipping tracking number.
*/

contract Store {
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
        uint256 id; // Product ID associated with the order
        uint256 productId;
        uint256 date;
        uint256 buyer; // EIN buyer
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
    struct Inventory {
        uint256 id;
        string name;
        bytes32[] skus;
    }
    // Seller ein => orders
    mapping(uint256 => Order[]) public pendingOrders; // The products waiting to be fulfilled
    // Buyer ein => orders
    mapping(uint256 => Order[]) public completedOrders;
    // Product id => product
    mapping(uint256 => Product) public productById;
    // Order id => order struct
    mapping(uint256 => Order) public orderById;
    Product[] public products;
    Inventory[] public inventories;
    uint256 public lastId;
    uint256 public lastOrderId;
    address public token;
    address public identityRegistry;

    /// @notice To setup the address of the ERC-721 token to use for this contract
    /// @param _token The token address
    constructor(address _token, address _identityRegistry) public {
        token = _token;
        identityRegistry = _identityRegistry;
    }

    /// @notice To publish a product as a seller
    /// @param _title The title of the product
    /// @param _description The description of the product
    /// @param _price The price of the product in ETH
    /// @param _image The image URL of the product
    function publishProduct(string memory _title, bytes32 _sku, string memory _description, uint256 _price, string memory _image, bytes32[] memory _attributes, bytes32[] _attributeValues, uint256 _quantity) public {
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
    function buyProduct(uint256 _id, string memory _nameSurname, string memory _lineOneDirection, string memory _lineTwoDirection, bytes32 _city, bytes32 _stateRegion, uint256 _postalCode, bytes32 _country, uint256 _phone, uint256 _barcode) public {
        // The line 2 address and phone are optional, the rest are mandatory
        require(bytes(_nameSurname).length > 0, 'The name and surname must be set');
        require(bytes(_lineOneDirection).length > 0, 'The line one direction must be set');
        require(_city.length > 0, 'The city must be set');
        require(_stateRegion.length > 0, 'The state or region must be set');
        require(_postalCode > 0, 'The postal code must be set');
        require(_country > 0, 'The country must be set');
        require(IdentityRegistryInterface(identityRegistry).hasIdentity(msg.sender), 'You must have an EIN associated with your Ethereum account to purchase the product');

        uint256 ein = IdentityRegistryInterface(identityRegistry).getEIN(msg.sender);
        Product memory p = productById[_id];
        require(bytes(p.title).length > 0, 'The product must exist to be purchased');
        require(HydroTokenTestnetInterface(token).allowance(msg.sender, address(this)) >= p.price, 'You must have enough HYDRO tokens approved to purchase this product');
        Order memory newOrder = Order(lastOrderId, _id, now, ein, _nameSurname, _lineOneDirection, _lineTwoDirection, _city, _stateRegion, _postalCode, _country, _phone, 'pending', _barcode);

        // Update the quantity of remaining products
        if(p.quantity > 0) {
            p.quantity--;
            productById[_id] = p;
        }

        pendingOrders[ein].push(newOrder);
        orderById[_id] = newOrder;
        HydroTokenTestnetInterface(token).transferFrom(msg.sender, p.owner, p.price); // Pay the product price to the seller
        lastOrderId++;
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

    /// @notice To delete a product
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

    /// @notice Returns the product length
    /// @return uint256 The number of products
    function getProductsLength() public view returns(uint256) {
        return products.length;
    }

    /// @notice To get the pending seller or buyer orders
    /// @param _type If you want to get the pending seller, buyer or completed orders
    /// @param _owner The owner of those orders
    /// @return uint256 The number of orders to get
    function getOrdersLength(bytes32 _type, address _owner) public view returns(uint256) {
        if(_type == 'pending') return pendingOrders[_owner].length;
        else if(_type == 'completed') return completedOrders[_owner].length;
    }
}
