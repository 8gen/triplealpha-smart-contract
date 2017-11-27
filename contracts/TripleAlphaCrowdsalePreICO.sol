pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './TripleAlphaTokenPreICO.sol';
import './Haltable.sol';
import './MultiOwners.sol';

 // @title TripleAlpha crowdsale contract
/**
 * The FixedRate contract does this and that...
 */
contract FixedRate {
    uint256 public rateETHUSD = 470e2;
}


contract Stage is FixedRate, MultiOwners {
    using SafeMath for uint256;

    // Global
    string _stageName = "Pre-ICO";

    // Maximum possible cap in USD
    uint256 public mainCapInUSD = 1000000e2;

    // Maximum possible cap in USD
    uint256 public hardCapInUSD = mainCapInUSD;

    //  period in days
    uint256 public period = 30 days;

    // Token Price in USD
    uint256 public tokenPriceUSD = 50;

    // WEI per token
    uint256 public weiPerToken;
    
    // start and end timestamp where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;

    // total wei received during phase one
    uint256 public totalWei;

    // Maximum possible cap in wei for phase one
    uint256 public mainCapInWei;
    // Maximum possible cap in wei
    uint256 public hardCapInWei;

    function Stage (uint256 _startTime) {
        startTime = _startTime;
        endTime = startTime.add(period);
        weiPerToken = tokenPriceUSD.mul(1 ether).div(rateETHUSD);
        mainCapInWei = mainCapInUSD.mul(1 ether).div(rateETHUSD);
        hardCapInWei = mainCapInWei;

    }

    /*
     * @dev amount calculation, depends of current period
     * @param _value ETH in wei
     * @param _at time
     */
    function calcAmountAt(uint256 _value, uint256 _at) constant returns (uint256, uint256) {
        uint256 estimate;
        uint256 odd;

        if(_value.add(totalWei) > hardCapInWei) {
            odd = _value.add(totalWei).sub(hardCapInWei);
            _value = hardCapInWei.sub(totalWei);
        } 
        estimate = _value.mul(1 ether).div(weiPerToken);
        require(_value + totalWei <= hardCapInWei);
        return (estimate, odd);
    }
}

 // @title TripleAlpha crowdsale contract
contract TripleAlphaCrowdsalePreICO is MultiOwners, Haltable, Stage {
    using SafeMath for uint256;

    // minimal token selled per time
    uint256 public minimalTokens = 1e18;

    // Sale token
    TripleAlphaTokenPreICO public token;

    // Withdraw wallet
    address public wallet;

    // Events
    event TokenPurchase(address indexed beneficiary, uint256 value, uint256 amount);
    event OddMoney(address indexed beneficiary, uint256 value);

    modifier validPurchase() {
        bool nonZeroPurchase = msg.value != 0;

        require(withinPeriod() && nonZeroPurchase);

        _;        
    }

    modifier isExpired() {
        require(now > endTime);

        _;        
    }

    /**
     * @return true if in period or false if not
     */
    function withinPeriod() constant returns(bool res) {
        return (now >= startTime && now <= endTime);
    }

    /**
     * @param _startTime Pre-ITO start time
     * @param _wallet destination fund address (i hope it will be multi-sig)
     */
    function TripleAlphaCrowdsalePreICO(uint256 _startTime, address _wallet) Stage(_startTime)

    {
        require(_startTime >= now);
        require(_wallet != 0x0);

        token = new TripleAlphaTokenPreICO();
        wallet = _wallet;
    }

    /**
     * @dev Human readable period Name 
     * @return current stage name
     */
    function stageName() constant public returns (string) {
        bool before = (now < startTime);
        bool within = (now >= startTime && now <= endTime);

        if(before) {
            return 'Not started';
        }

        if(within) {
            return _stageName;
        } 

        return 'Finished';
    }

    
    function totalEther() public constant returns(uint256) {
        return totalWei.div(1e18);
    }

    /*
     * @dev fallback for processing ether
     */
    function() payable {
        return buyTokens(msg.sender);
    }

    /*
     * @dev sell token and send to contributor address
     * @param contributor address
     */
    function buyTokens(address contributor) payable stopInEmergency validPurchase public {
        uint256 amount;
        uint256 odd_ethers;
        
        (amount, odd_ethers) = calcAmountAt(msg.value, now);
  
        require(contributor != 0x0) ;
        require(minimalTokens <= amount);

        token.mint(contributor, amount);
        TokenPurchase(contributor, msg.value, amount);

        totalWei = totalWei.add(msg.value);

        if(odd_ethers > 0) {
            require(odd_ethers < msg.value);
            OddMoney(contributor, odd_ethers);
            contributor.transfer(odd_ethers);
        }

        wallet.transfer(this.balance);
    }

    /*
     * @dev finish crowdsale
     */
    function finishCrowdsale() onlyOwner public {
        require(now > endTime || totalWei == hardCapInWei);
        require(!token.mintingFinished());
        token.finishMinting();
    }

    // @return true if crowdsale event has ended
    function running() constant public returns (bool) {
        return withinPeriod() && !token.mintingFinished();
    }
}