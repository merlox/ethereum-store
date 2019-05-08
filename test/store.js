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
        console.log(token.address, identityRegistry.address)
    })
    it('a', () => {

    })
})
