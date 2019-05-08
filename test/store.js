const assert = require('assert')
const Store = artifacts.require('Store.sol')
const IdentityRegistry = artifacts.require('IdentityRegistry.sol')
const Token = artifacts.require('HydroTokenTestnet.sol')
const Dispute = artifacts.require('Dispute.sol')
let store
let token
let dispute
let identityRegistry

contract('Store', accounts => {
    beforeEach(async () => {
        // address _token, address _identityRegistry
        token = await Token.new()
        identityRegistry = await IdentityRegistry.new()
        store = await Store.new(token.address, identityRegistry.address)
        dispute = await Dispute.new(store.address)
    })
    it('should create a product successfully')
    it('should purchase a product successfully')
    it('should delete a product successfully')
    it('should create an inventory successfully')
    it('should delete an inventory successfully')
    it('should mark an order as completed')
})
