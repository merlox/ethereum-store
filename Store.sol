/*
Create a SKU - assign a unique ID to a product
- With ecommerce-dapp contract

Define attributes - define the attributes of the product to store on-chain, such as gender, size, color, materials
- Attributes will be stored in an array of bytes32[] and the values will be bytes32[]. If it's a number, you simply convert it to string.

Inventory - add a SKU to a group of other SKUs to form the foundation of inventory management
- Create an inventory struct containing products or use mappings or arrays

Shipping - define shipping parameters of the SKU or inventory
- Create a shipping or order struct by using ecommerce-dapp

Price - define price of the SKU or inventory, accept gift cards and coupons from other Hydro Snowflake smart contracts
- To be determined

Create Order - create an order, tied to a Snowflake ID of a business and an end-user containing date, SKU info, shipping info
- Can be done with ecommerce-dapp + IdentityRegistryInterface.identityExists(ein) +  IdentityRegistryInterface.hasIdentity(address) + IdentityRegistryInterface.getEIN(address)

Create Barcode - create a unique barcode tied to an order
- Barcode js https://lindell.me/JsBarcode/

Authenticate Purchase - use Hydro Raindrop to confirm a purchase
- To be determined

Authenticate Shipment - perform an authentication of the SKU(s) being sent and reduce from inventory
- Reduce the inventory in the smart contract only

Authenticate Receipt - perform an authentication of the product SKU being received by scanning the barcode and storing in the Snowflake
- to be determined

Dispute - create a flag on a Snowflake for a disputed order or shipment
- After a user has purchased a product, he has the option to call the function disputeOrder() while providing a string explaining his situation. An event will be emitted and the seller will be able to call the function counterDisputeOrder() to provide an explanation of the situation. After that, an approved operator will be able to determine how's right. The seller is expected to provide the shipping tracking number.
*/
