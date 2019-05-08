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
        // const title = 'This is an example'
        // const sku = bytes32('2384jd93nf')
        // const description = 'This is the description of the product'
        // const price = 200
        // const image = 'https://example.com'
        // const attributes = [bytes32('size'), bytes32('color')]
        // const attributeValues = [bytes32('s'), bytes32('m'), bytes32('x'), bytes32('red'), bytes32('blue'), bytes32('green')]
        // const quantity = 5
        //
        // // Create the product
        // await store.publishProduct(title, sku, description, price, image, attributes, attributeValues, quantity)
        // const product = await store.products(0)
        // console.log('Product', product)
    })
    it('should purchase a product successfully')
    it('should delete a product successfully')
    it('should create an inventory successfully')
    it('should delete an inventory successfully')
    it('should mark an order as completed')
})
