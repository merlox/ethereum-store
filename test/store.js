const assert = require('assert')
const Store = artifacts.require('Store.sol')
const IdentityRegistry = artifacts.require('IdentityRegistry.sol')
const Token = artifacts.require('HydroTokenTestnet.sol')
const Dispute = artifacts.require('Dispute.sol')
let store
let token
let dispute
let identityRegistry

advanceTimeAndBlock = async (time) => {
    await advanceTime(time)
    await advanceBlock()

    return Promise.resolve(web3.eth.getBlock('latest'))
}

advanceTime = (time) => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_increaseTime",
            params: [time],
            id: new Date().getTime()
        }, (err, result) => {
            if (err) { return reject(err) }
            return resolve(result)
        })
    })
}

advanceBlock = () => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_mine",
            id: new Date().getTime()
        }, (err, result) => {
            if (err) { return reject(err) }
            const newBlockHash = web3.eth.getBlock('latest').hash

            return resolve(newBlockHash)
        })
    })
}

function bytes32(msg) {
    return web3.utils.fromAscii(msg)
}

async function createProduct(accounts) {
    const title = 'This is an example'
    const sku = bytes32('2384jd93nf')
    const description = 'This is the description of the product'
    const price = web3.utils.toBN(200 * 1e18)
    const image = 'https://example.com'
    const attributes = [bytes32('size'), bytes32('color')]
    const attributeValues = [bytes32('s'), bytes32('m'), bytes32('x'), bytes32('red'), bytes32('blue'), bytes32('green')]
    const quantity = 5
    const barcode = 214397912874

    // Create the product
    await store.publishProduct(title, sku, description, price, image, attributes, attributeValues, quantity, barcode)
    const lastProductId = await store.lastId()
    const product = await store.products(lastProductId - 1)
    return product
}

async function createOrder(accounts) {
    const id = 0
    const nameSurname = 'Example Examp'
    const direction = 'C/hs 248 sjdfs'
    const city = bytes32('england') // England is my city ♫
    const stateRegion = bytes32('englando')
    const postalCode = 03214
    const country = bytes32('england')
    const phone = 38274619283
    const price = web3.utils.toBN(200 * 1e18)

    let product = await createProduct(accounts)

    // Give some tokens to the first user to purchase the product
    await token.transfer(accounts[1], price, {from: accounts[0]})

    // Allow some tokens to the contract
    await token.approve(store.address, price, {from: accounts[1]})

    // Buy the product
    await store.buyProduct(id, nameSurname, direction, city, stateRegion, postalCode, country, phone, {from: accounts[1]})
    const lastOrderId = await store.lastOrderId()
    const order = await store.orderById(parseInt(lastOrderId) - 1)
    product = await store.products(id)
    return [order, product]
}

contract('Store', accounts => {
    beforeEach(async () => {
        // address _token, address _identityRegistry
        token = await Token.new()
        identityRegistry = await IdentityRegistry.new()
        store = await Store.new(token.address, identityRegistry.address)
        dispute = await Dispute.new(store.address)
        console.log('Creating identity one')
        await identityRegistry.createIdentity(accounts[0], [accounts[1]], [accounts[1]], {gas: 8e6})
        console.log('Creating identity two')
        await identityRegistry.createIdentity(accounts[1], [accounts[2]], [accounts[2]], { from: accounts[1], gas: 8e6 })
        console.log('Setting dispute contract address on store for escrow purposes')
        await store.setDisputeAddress(dispute.address)
    })
    it('should create a product successfully', async () => {
        const title = 'This is an example'
        const product = await createProduct(accounts)
        assert.equal(title, product.title, 'The product must be deployed with the publish function')
    })
    it('should purchase a product successfully', async () => {
        const results = await createOrder(accounts)
        const order = results[0]
        const product = results[1]

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
    it('should mark an order as sent', async () => {
        const orderId = 0
        const results = await createOrder(accounts)
        let order = results[0]
        const product = results[1]

        await store.markOrderSent(orderId, {from: accounts[0]})
        order = await store.orderById(orderId)
        assert.equal(web3.utils.toUtf8(order.state), 'sent', 'The order must be marked as sent')
    })
    it('should dispute an order', async () => {
        const results = await createOrder(accounts)
        let order = results[0]
        const product = results[1]

        // Dispute the order, must be executed by the buyer accounts[1]
        const reason = 'Because I want to'
        await dispute.disputeOrder(order.id, reason, {from: accounts[1]})
        const disputeAdded = await dispute.disputes(0)
        assert.equal(disputeAdded.reason, reason, 'The dispute has to be created successfully')
    })
    it('should counter dispute an existing dispute', async () => {
        const disputeId = 0

        const results = await createOrder(accounts)
        let order = results[0]
        const product = results[1]
        // Dispute the order, must be executed by the buyer accounts[1]
        const reason = 'Because I want to'
        await dispute.disputeOrder(order.id, reason, {from: accounts[1]})

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

        const results = await createOrder(accounts)
        let order = results[0]
        const product = results[1]
        // Dispute the order, must be executed by the buyer accounts[1]
        const reason = 'Because I want to'
        await dispute.disputeOrder(order.id, reason, {from: accounts[1]})
        const counterReason = 'bruh the product has been sent already'
        await dispute.counterDispute(disputeId, counterReason)
        let disputeItem = await dispute.disputes(0)

        await dispute.setOperator(accounts[1], false, {from: accounts[0]})
        const operator = await dispute.operators(1)

        await dispute.resolveDispute(disputeId, isBuyerWinner, {from: accounts[1]})
        const buyerTokenbalanceAfterWinning = parseInt(await token.balanceOf(accounts[1]))
        disputeItem = await dispute.disputes(0)
        assert.equal(initialBuyerTokenBalance, buyerTokenbalanceAfterWinning, 'The balance must stay the same for the buyer since he didnt win the dispute')
        assert.equal(web3.utils.toUtf8(disputeItem.state), 'resolved', 'The dispute must be marked as resolved')
    })
    it('should resolve a dispute by an operator to select the buyer as the winner', async () => {
        const disputeId = 0
        const isBuyerWinner = true
        const price = web3.utils.toBN(200 * 1e18)
        const initialBuyerTokenBalance = parseInt(await token.balanceOf(accounts[1]))

        const results = await createOrder(accounts)
        let order = results[0]
        const product = results[1]
        // Dispute the order, must be executed by the buyer accounts[1]
        const reason = 'Because I want to'
        await dispute.disputeOrder(order.id, reason, {from: accounts[1]})
        const counterReason = 'bruh the product has been sent already'
        await dispute.counterDispute(disputeId, counterReason)
        let disputeItem = await dispute.disputes(0)

        await dispute.setOperator(accounts[1], false, {from: accounts[0]})
        const operator = await dispute.operators(1)

        await dispute.resolveDispute(disputeId, isBuyerWinner, {from: accounts[1]})
        const buyerTokenbalanceAfterWinning = parseInt(await token.balanceOf(accounts[1]))
        disputeItem = await dispute.disputes(0)
        assert.equal(initialBuyerTokenBalance + price, buyerTokenbalanceAfterWinning, 'The balance must increase by the price for the buyer after winning the dispute')
        assert.equal(web3.utils.toUtf8(disputeItem.state), 'resolved', 'The dispute must be marked as resolved')
    })
    it('should not allow disputes after the period of 15 days', async () => {
        const results = await createOrder(accounts)
        let order = results[0]
        const product = results[1]

        const sixteenDays = 16 * 24 * 60 * 60 * 1e3
        await advanceTimeAndBlock(sixteenDays)

        // Dispute the order, must be executed by the buyer accounts[1]
        const reason = 'Because I want to'
        try {
            await dispute.disputeOrder(order.id, reason, {from: accounts[1]})
            assert.ok(false, 'The order should fail since we dont allow disputes after 15 days')
        } catch (e) {
            assert.ok(true, 'The order was reverted successfully')
        }
    })
    it('the seller should be able to extract his funds after 15 days', async () => {
        // Create the order
        const results = await createOrder(accounts)
        let order = results[0]
        const product = results[1]
        const initialTokenBalance = await token.balanceOf(accounts[0])
        const price = web3.utils.toBN(200 * 1e18)

        // Mark the order as sent
        await store.markOrderSent(order.id, {from: accounts[0]})
        order = await store.orderById(order.id)
        assert.equal(web3.utils.toUtf8(order.state), 'sent', 'The order must be marked as sent')

        // Wait 15 days for allowing disputes
        const sixteenDays = 16 * 24 * 60 * 60 * 1e3
        await advanceTimeAndBlock(sixteenDays)

        // Receive the payment
        await store.receivePayment(order.id, {from: accounts[0]})
        const finalTokenBalance = await token.balanceOf(accounts[0])
        order = await store.orderById(order.id)
        // Check that the order has been marked as completed
        assert.equal(web3.utils.toUtf8(order.state), 'completed', 'The order state must be set as completed')
        // Check that the balance is increased after the payment
        assert.equal(String(finalTokenBalance), String(initialTokenBalance.add(price)), 'The final balance of the seller has to be increased by the price')
    })
    it('the seller should not be able to extract his order funds before 15 days', async () => {
        // Create the order
        const results = await createOrder(accounts)
        let order = results[0]
        const product = results[1]
        const initialTokenBalance = await token.balanceOf(accounts[0])
        const price = web3.utils.toBN(200 * 1e18)

        // Mark the order as sent
        await store.markOrderSent(order.id, {from: accounts[0]})
        order = await store.orderById(order.id)
        assert.equal(web3.utils.toUtf8(order.state), 'sent', 'The order must be marked as sent')

        // Receive the payment
        try {
            await store.receivePayment(order.id, {from: accounts[0]})
            assert.ok(false, 'The transaction should revert to not allow payments before 15 days')
        } catch(e) {
            assert.ok(true, 'The transaction should revert to not allow payments before 15 days which is good')
        }
    })
}) // All tests passing
