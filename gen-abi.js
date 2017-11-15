var abi = require('ethereumjs-abi')

var encoded = abi.rawEncode([ "uint256","uint256", "address" ], [
    1510012800,
    1512086400, 
    "0x1968cA762Be67170BDbAC3E92b0994C94396ce8e", // Main Wallet (3)
]);

console.log(encoded.toString('hex'));
