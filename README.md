# Ethereum Hydro Store
The Ethereum store for hydro smart contracts. It allows you to publish products, purchase them with HYDRO and dispute orders in case there's any problem. Remember to install all the dependencies with `npm i` before running the tests or using the contracts. All the contract code is stored inside the `contracts` folder.

## Contracts
There are 2 main contracts:
- Store.sol contract: This is the main contract and it is used to create products, inventories, purchase products, mark orders as sent and to receive payments as a seller. This contract also works as an escrow to hold funds for 15 days in case the buyers wants to flag an invalid order.
- Dispute.sol contract: This one is used to dispute orders for those users that have problems with a specific product within a 15 day period since it is quite complex, it had to be separated into a new contract.

## Deployment Process
To deploy both contracts you must follow these steps:
1. Deploy or get the address of an existing HYDRO token
2. Deploy or get the address of an existing Identity Registry contract for managing EINs
3. Deploy a new Store contract passing the token and identityRegistry addresses in the constructor
4. Deploy a new Dispute contract with the deployed Store address
5. Set the address of the dispute contract on the Store by using the function `setDisputeAddress()`. This is required to allow the Dispute contract to offer refunds in case the user has problems with his order.
After those steps you should be able to use both contracts successfully.

### Product Creation
The first thing that you'll want to do, is to create products. You can do so with the function `publishProduct()` which requires the title, sky, description, price, imageUrl, attributes, attributeValues, quantity and barcode as parameters for the product that you want to create.

Your must have an EIN associated with your address to publish the product.

- The ImageUrl is just a valid string with the online image that you want to use for your product.

- The `attributes` array is made of bytes32 strings and you specify all the attributes that you want. For instance: size, color and material or `['size', 'color', 'material']`

- The `attributeValues` is another array containing all the values in order for all the attributes. For instance, if you have the attributes color and size, the `attributeValues` will contain: `['red', 'blue', 'yellow', 'green', 'S', 'M', 'L']`. Essentially, a list of all the values combined.

- The quantity of each product gets automatically updated when a user purchases said product until there are no more products left. You can't purchase a product with quantity zero.

- The barcode of the product is a large digit that you can generate with the javascript utility Barcode Js https://lindell.me/JsBarcode/. It must be generated locally. You should register the barcode on a public barcode registry if you want it to be valid globally.

### Inventory Creation
Inventories are great ways of creating collections made of specific products that you want to organize in neat lists. You can create an inventory with the function `createInventory(string memory _name, bytes32[] memory _skus)` which receives the name of the inventory and the array of skus that you want to add to that list.

### Purchasing Products
After a user has created a product with a quantity larger than zero, you can buy said product with the function: `buyProduct(uint256 _id, string memory _nameSurname, string memory _direction, bytes32 _city, bytes32 _stateRegion, uint256 _postalCode, bytes32 _country, uint256 _phone)` which requires the id of the product to buy, your name and surname, the direction of where you live, your city, your state or region, your postal code, your country, your phone number and the barcode of the product you want to purchase.

To buy the product you must first create a token allowance of the price of the product to the store contract so that it able to move your HYDRO funds to the escrow. For instance, if the product price is 200 HYDRO, you must run the `token.approve(storeAddress, 200 HYDRO)` function with 200 tokens to the store address.

Your must have an EIN associated with your address to buy the product.

After buying the product, the seller will be able to mark it as sent.

### Sending Products
After a product is purchased, an Order object will be created with all the required fields so that sellers can immediately send the product. After the product is sent, the seller will have to execute the function `store.markOrderSent(orderId)` so that the Order state gets updated, letting the buyer know that the product has been shipped.

### Dispute Process
Disputes are an essential part of any decent store that cares about customers since there will be products with shipping times and users that want to benefit from the system.

When a product is purchased, the seller will have to mark it as sent with the previous function. Then, there will be a period of 15 days in which the buyer can create a dispute with the function from the Dispute contract `dispute.disputeOrder(uint256 _id, string memory _reason)` which receives the id of the order and the reason for disputing it.

The dispute process will be started and the seller will have to run the `counterDispute(uint256 _disputeId, string memory _counterReason)` function which takes the dispute Id and the counter reason for defending his position.

Once that is done, an external operator will decide who is the winner of the argument with the function `resolveDispute(uint256 _disputeId, bool _isBuyerWinner)` with the dispute Id and whether or not the buyer is the winner as the parameters. If the buyer is the winner, the price of the purchased product will be refunded to him and the seller will lose his money. Otherwise, the seller will win his sale.

Operators are valid addresses that can resolve disputes. Initially, the deployer (owner) of the dispute contract is the first approved operator and he can create new operators with the function `setOperator(address _user, bool _isRemoved)` which takes the address of the user to set as operator and whether or not he wants to remove that operator or include it to the list of approved operators. That function can be used for adding or deleting operators as you can see. Only the owner can control who's approved.

## Tests
There are 12 tests that are passing successfully to verify all the key features of this dApp. To run them, create a ganache instance with an increased gas limit of about 8 million to be able to deploy the store contract, since it's quite large. Do so with the following command:

```
ganache-cli -l 0x81B320
```

Then you can run the tests by using:

```
truffle test
```
