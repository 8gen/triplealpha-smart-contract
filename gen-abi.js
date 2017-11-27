var abi = require('ethereumjs-abi')

var encoded = abi.rawEncode([ "uint256", "address" ], [
    1511777494, "0x008290B1f0C771984Ec459c8836A245eCCA95797"
]);

console.log(encoded.toString('hex'));
