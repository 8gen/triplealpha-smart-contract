pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';


contract TripleAlphaTokenPreICO is MintableToken {

    string public constant name = 'Triple Alpha Token Pre-ICO';
    string public constant symbol = 'pTRIA';
    uint8 public constant decimals = 18;

    function transferFrom(address from, address to, uint256 value) returns (bool) {
        revert();
    }

    function transfer(address to, uint256 value) returns (bool) {
        revert();
    }
}
