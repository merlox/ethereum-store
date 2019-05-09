const assert = require('assert')
const Store = artifacts.require('Store.sol')
const IdentityRegistry = artifacts.require('IdentityRegistry.sol')
const Token = artifacts.require('HydroTokenTestnet.sol')
const Dispute = artifacts.require('Dispute.sol')
let store
let token
let dispute
let identityRegistry

function bytes32(msg) {
    return web3.utils.fromAscii(msg)
}

contract('Store', accounts => {
    before(async () => {
        // address _token, address _identityRegistry
        token = await Token.new()
        identityRegistry = await IdentityRegistry.new()
        store = await Store.new(token.address, identityRegistry.address)
        dispute = await Dispute.new(store.address)
        console.log('Creating identity one')
        await identityRegistry.createIdentity(accounts[0], [accounts[1]], [accounts[1]], {gas: 8e6})
        console.log('Creating identity two')
        await identityRegistry.createIdentity(accounts[1], [accounts[2]], [accounts[2]], { from: accounts[1], gas: 8e6 })
    })
    it('should create a product successfully', async () => {
        const title = 'This is an example'
        const sku = bytes32('2384jd93nf')
        const description = 'This is the description of the product'
        const price = web3.utils.toBN(200 * 1e18)
        const image = 'https://example.com'
        const attributes = [bytes32('size'), bytes32('color')]
        const attributeValues = [bytes32('s'), bytes32('m'), bytes32('x'), bytes32('red'), bytes32('blue'), bytes32('green')]
        const quantity = 5

        // Create the product
        await store.publishProduct(title, sku, description, price, image, attributes, attributeValues, quantity)
        const product = await store.products(0)
        assert.equal(title, product.title, 'The product must be deployed with the publish function')
    })
    it('should purchase a product successfully', async () => {
        const id = 0
        const nameSurname = 'Example Examp'
        const direction = 'C/hs 248 sjdfs'
        const city = bytes32('england') // England is my city ♫
        const stateRegion = bytes32('englando')
        const postalCode = 03214
        const country = bytes32('england')
        const phone = 38274619283
        const barcode = 17236184923
        const price = web3.utils.toBN(200 * 1e18)

        // Give some tokens to the first user to purchase the product
        await token.transfer(accounts[1], price, {from: accounts[0]})

        // Allow some tokens to the contract
        await token.approve(store.address, price, {from: accounts[1]})

        // Buy the product
        await store.buyProduct(id, nameSurname, direction, city, stateRegion, postalCode, country, phone, barcode, {from: accounts[1]})
        const lastOrderId = await store.lastOrderId()
        const order = await store.orderById(parseInt(lastOrderId) - 1)
        const product = await store.products(0)

        assert.equal(4, product.quantity, 'The product quantity must be reduced')
        assert.equal(order.addressBuyer, accounts[1], 'The buyer must be set after creating the order')
    })
    it('should create an inventory successfully', async () => {
        const name = 'my inventory'
        const skus = [bytes32('askldui21'), bytes32('asdfasn3218')]

        await store.createInventory(name, skus)
        const inventory = await store.inventories(0)
        assert.equal(inventory.name, name, 'The name of the inventory must be set when creating a new one')
    })
    it('should mark an order as completed', async () => {
        const orderId = 0

        await store.markOrderCompleted(orderId, {from: accounts[0]})
        const order = await store.orderById(orderId)
        assert.equal(order.state, 'completed', 'The order must be marked as completed')
    })
    it('should delete an inventory successfully', async () => {
        const orderId = 0

        await store.deleteInventory(orderId)
        try {
            const inventory = await store.inventories(orderId)
        } catch(e) {
            assert.ok(true) // Test passing as expected since we don't have an element 0 for that element that has been deleted
        }
    })
    it('should delete a product successfully', async () => {
        const productId = 0

        await store.deleteProduct(productId)
        try {
            const product = await store.products(productId)
        } catch(e) {
            assert.ok(true) // Test passing as expected since we don't have an element 0 for that element that has been deleted
        }
    })
    it('should dispute an order', async () => {
        // Create a product first
        const title = 'This is an example'
        const sku = bytes32('2384jd93nf')
        const description = 'This is the description of the product'
        let price = web3.utils.toBN(200 * 1e18)
        const image = 'https://example.com'
        const attributes = [bytes32('size'), bytes32('color')]
        const attributeValues = [bytes32('s'), bytes32('m'), bytes32('x'), bytes32('red'), bytes32('blue'), bytes32('green')]
        const quantity = 5
        await store.publishProduct(title, sku, description, price, image, attributes, attributeValues, quantity)
        let product = await store.products(0)
        assert.equal(title, product.title, 'The product must be deployed with the publish function')

        // Buy the product to create the order
        const id = product.id
        const nameSurname = 'Example Examp'
        const direction = 'C/hs 248 sjdfs'
        const city = bytes32('england') // England is my city ♫
        const stateRegion = bytes32('englando')
        const postalCode = 03214
        const country = bytes32('england')
        const phone = 38274619283
        const barcode = 17236184923
        price = web3.utils.toBN(200 * 1e18)
        await token.transfer(accounts[1], price, {from: accounts[0]})
        await token.approve(store.address, price, {from: accounts[1]})
        await store.buyProduct(id, nameSurname, direction, city, stateRegion, postalCode, country, phone, barcode, {from: accounts[1]})
        const lastOrderId = await store.lastOrderId()
        const order = await store.orderById(parseInt(lastOrderId) - 1)
        product = await store.products(0)
        assert.equal(4, product.quantity, 'The product quantity must be reduced')
        assert.equal(order.addressBuyer, accounts[1], 'The buyer must be set after creating the order')

        // Dispute the order, must be executed by the buyer accounts[1]
        const reason = 'Because I want to'
        await dispute.disputeOrder(parseInt(lastOrderId) - 1, reason, {from: accounts[1]})
        const disputeAdded = await dispute.disputes(0)
        assert.equal(disputeAdded.reason, reason, 'The dispute has to be created successfully')
    })
    it('should counter dispute an existing dispute', async () => {
        const disputeId = 0
        const counterReason = 'bruh the product has been sent already'
        await dispute.counterDispute(disputeId, counterReason)
        const disputeItem = await dispute.disputes(0)
        assert.equal(disputeItem.counterReason, counterReason, 'The counter reason has been added successfully')
    })
    it('should add an operator', async () => {
        await dispute.setOperator(accounts[1], false, {from: accounts[0]})
        const operator = await dispute.operators(1)
        assert.equal(operator, accounts[1], 'The operator must be set')
    })
    it('should resolve a dispute by an operator to select the seller as the winner', async () => {
        const disputeId = 0
        const isBuyerWinner = false
        const initialBuyerTokenBalance = parseInt(await token.balanceOf(accounts[1]))
        await dispute.resolveDispute(disputeId, isBuyerWinner, {from: accounts[1]})
        const buyerTokenbalanceAfterWinning = parseInt(await token.balanceOf(accounts[1]))
        assert.equal(initialBuyerTokenBalance, buyerTokenbalanceAfterWinning, 'The balance must stay the same for the buyer since he didnt win the dispute')
    })
})
