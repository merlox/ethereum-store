const assert = require('assert')
const Store = artifacts.require('Store.sol')
let store
let token
let identityRegistry

contract('Store', accounts => {
    beforeEach(async () => {
        // address _token, address _identityRegistry
        store = await Store.new()

    })
})
