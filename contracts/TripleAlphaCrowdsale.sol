pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './TripleAlphaToken.sol';
import './Haltable.sol';
import './MultiOwners.sol';


 // @title TripleAlpha crowdsale contract
contract TripleAlphaCrowdsale is MultiOwners, Haltable {
    using SafeMath for uint256;

    // Global
    // ETHUSD change rate
    uint256 public rateETHUSD;

    // minimal token selled per time
    uint256 public minimalTokens = 1e18;

    // Sale token
    TripleAlphaToken public token;

    // Withdraw wallet
    address public wallet;

    // Pre-ICO
    // Maximum possible cap in USD on PREITO
    uint256 public PREITOmainCapInUSD = 1000000e2;

    // Maximum possible cap in USD on PREITO
    uint256 public PREITOhardCapInUSD = PREITOmainCapInUSD;

    // PreITO period in days
    uint256 public PREITOperiod = 30 days;

    // Token Price in USD
    uint256 public PREITOtokenPriceUSD = 50;

    // WEI per token
    uint256 public PREITOweiPerToken;
    
    // start and end timestamp where investments are allowed (both inclusive)
    uint256 public PREITOstartTime;
    uint256 public PREITOendTime;

    // total wei received during phase one
    uint256 public PREITOwei;

    // Maximum possible cap in wei for phase one
    uint256 public PREITOmainCapInWei;
    // Maximum possible cap in wei
    uint256 public PREITOhardCapInWei;


    // ICO
    // Minimal possible cap in USD on ITO
    uint256 public ITOsoftCapInUSD = 1000000e2;

    // Maximum possible cap in USD on ITO
    uint256 public ITOmainCapInUSD = 8000000e2;

    uint256 public ITOperiod = 60 days;

    // Maximum possible cap in USD on ITO
    uint256 public ITOhardCapInUSD = ITOsoftCapInUSD + ITOmainCapInUSD;

    // Token Price in USD
    uint256 public ITOtokenPriceUSD = 100;

    // WEI per token
    uint256 public ITOweiPerToken;

    // start and end timestamp where investments are allowed (both inclusive)
    uint256 public ITOstartTime;
    uint256 public ITOendTime;

    // total wei received during phase two
    uint256 public ITOwei;
    
    // refund if softCap is not reached
    bool public refundAllowed = false;

    // need for refund
    mapping(address => uint256) public received_ethers;


    // Hard possible cap - soft cap in wei for phase two
    uint256 public ITOmainCapInWei;

    // Soft cap in wei
    uint256 public ITOsoftCapInWei;

    // Hard possible cap - soft cap in wei for phase two
    uint256 public ITOhardCapInWei;


    // Events
    event TokenPurchase(address indexed beneficiary, uint256 value, uint256 amount);
    event OddMoney(address indexed beneficiary, uint256 value);
    event SetPREITOstartTime(uint256 new_startTimePREITO);
    event SetITOstartTime(uint256 new_startTimeITO);

    modifier validPurchase() {
        bool nonZeroPurchase = msg.value != 0;

        require(withinPeriod() && nonZeroPurchase);

        _;        
    }

    modifier isExpired() {
        require(now > ITOendTime);

        _;        
    }

    /**
     * @return true if in period or false if not
     */
    function withinPeriod() constant returns(bool res) {
        bool withinPREITO = (now >= PREITOstartTime && now <= PREITOendTime);
        bool withinITO = (now >= ITOstartTime && now <= ITOendTime);
        return (withinPREITO || withinITO);
    }
    

    /**
     * @param _PREITOstartTime Pre-ITO start time
     * @param _ITOstartTime ITO start time
     * @param _wallet destination fund address (i hope it will be multi-sig)
     */
    function TripleAlphaCrowdsale(uint256 _PREITOstartTime, uint256 _ITOstartTime, address _wallet) {
        require(_PREITOstartTime >= now);
        require(_ITOstartTime > _PREITOstartTime);
        require(_wallet != 0x0);

        token = new TripleAlphaToken();
        wallet = _wallet;

        _changeEthPrice(300e2);
        setPREITOstartTime(_PREITOstartTime);
        setITOstartTime(_ITOstartTime);
        require(rateETHUSD > 0);
    }

    /**
     * @dev Human readable period Name 
     * @return current stage name
     */
    function stageName() constant public returns (string) {
        bool beforePreITO = (now < PREITOstartTime);
        bool withinPreITO = (now >= PREITOstartTime && now <= PREITOendTime);
        bool betweenPreITOAndITO = (now >= PREITOendTime && now <= ITOstartTime);
        bool withinITO = (now >= ITOstartTime && now <= ITOendTime);

        if(beforePreITO) {
            return 'Not started';
        }

        if(withinPreITO) {
            return 'Pre-ITO';
        } 

        if(betweenPreITOAndITO) {
            return 'Between Pre-ITO and ITO';
        }

        if(withinITO) {
            return 'ITO';
        }

        return 'Finished';
    }

    /**
     * @dev Human readable period Name 
     * @return current stage name
     */
    function totalWei() public constant returns(uint256) {
        return PREITOwei + ITOwei;
    }
    
    function totalEther() public constant returns(uint256) {
        return totalWei().div(1e18);
    }

    /*
     * @dev update PreITO start time
     * @param _at new start date
     */
    function setPREITOstartTime(uint256 _at) onlyOwner {
        require(PREITOstartTime == 0 || block.timestamp < PREITOstartTime); // forbid change time when first phase is active
        require(block.timestamp < _at); // should be great than current block timestamp
        require(ITOstartTime == 0 || _at < ITOstartTime); // should be lower than start of second phase

        PREITOstartTime = _at;
        PREITOendTime = PREITOstartTime.add(PREITOperiod);
        SetPREITOstartTime(_at);
    }

    /*
     * @dev update ITO start date
     * @param _at new start date
     */
    function setITOstartTime(uint256 _at) onlyOwner {
        require(ITOstartTime == 0 || block.timestamp < ITOstartTime); // forbid change time when second phase is active
        require(block.timestamp < _at); // should be great than current block timestamp
        require(PREITOendTime < _at); // should be great than end first phase

        ITOstartTime = _at;
        ITOendTime = ITOstartTime.add(ITOperiod);
        SetITOstartTime(_at);
    }

    function ITOsoftCapReached() internal returns (bool) {
        return ITOwei >= ITOsoftCapInWei;
    }

    /*
     * @dev fallback for processing ether
     */
    function() payable {
        return buyTokens(msg.sender);
    }

    /*
     * @dev amount calculation, depends of current period
     * @param _value ETH in wei
     * @param _at time
     */
    function calcAmountAt(uint256 _value, uint256 _at) constant public returns (uint256, uint256) {
        uint256 estimate;
        uint256 odd;

        if(_at < PREITOendTime) {
            if(_value.add(PREITOwei) > PREITOhardCapInWei) {
                odd = _value.add(PREITOwei).sub(PREITOhardCapInWei);
                _value = PREITOhardCapInWei.sub(PREITOwei);
            } 
            estimate = _value.mul(1 ether).div(PREITOweiPerToken);
            require(_value + PREITOwei <= PREITOhardCapInWei);
        } else {
            if(_value.add(ITOwei) > ITOhardCapInWei) {
                odd = _value.add(ITOwei).sub(ITOhardCapInWei);
                _value = ITOhardCapInWei.sub(ITOwei);
            }             
            estimate = _value.mul(1 ether).div(ITOweiPerToken);
            require(_value + ITOwei <= ITOhardCapInWei);
        }

        return (estimate, odd);
    }

    /*
     * @dev sell token and send to contributor address
     * @param contributor address
     */
    function buyTokens(address contributor) payable stopInEmergency validPurchase public {
        uint256 amount;
        uint256 odd_ethers;
        bool transfer_allowed = true;
        
        (amount, odd_ethers) = calcAmountAt(msg.value, now);
  
        require(contributor != 0x0) ;
        require(minimalTokens <= amount);

        token.mint(contributor, amount);
        TokenPurchase(contributor, msg.value, amount);

        if(now < PREITOendTime) {
            // Pre-ITO
            PREITOwei = PREITOwei.add(msg.value);

        } else {
            // ITO
            if(ITOsoftCapReached()) {
                ITOwei = ITOwei.add(msg.value).sub(odd_ethers);
            } else if(this.balance >= ITOsoftCapInWei) {
                ITOwei = this.balance.sub(odd_ethers);
            } else {
                received_ethers[contributor] = received_ethers[contributor].add(msg.value);
                transfer_allowed = false;
            }
        }

        if(odd_ethers > 0) {
            require(odd_ethers < msg.value);
            OddMoney(contributor, odd_ethers);
            contributor.transfer(odd_ethers);
        }

        if(transfer_allowed) {
            wallet.transfer(this.balance);
        }
    }

    /*
     * @dev sell token and send to contributor address
     * @param contributor address
     */
    function refund() isExpired public {
        require(refundAllowed);
        require(!ITOsoftCapReached());
        require(received_ethers[msg.sender] > 0);
        require(token.balanceOf(msg.sender) > 0);

        uint256 current_balance = received_ethers[msg.sender];
        received_ethers[msg.sender] = 0;
        token.burn(msg.sender);
        msg.sender.transfer(current_balance);
    }

    /*
     * @dev change eth price
     */
    function changeEthPrice(uint256 _price) onlyOwner public {
        require(_price > 0);
        require(!token.mintingFinished());

        _changeEthPrice(_price);
   }

    function _changeEthPrice(uint256 _price) internal {
        rateETHUSD = _price;
        PREITOweiPerToken = PREITOtokenPriceUSD.mul(1 ether).div(_price);
        PREITOmainCapInWei = PREITOmainCapInUSD.mul(1 ether).div(_price);
        PREITOhardCapInWei = PREITOmainCapInWei;

        ITOweiPerToken = ITOtokenPriceUSD.mul(1 ether).div(_price);
        ITOmainCapInWei = ITOmainCapInUSD.mul(1 ether).div(_price);
        ITOsoftCapInWei = ITOsoftCapInUSD.mul(1 ether).div(_price);
        ITOhardCapInWei = ITOsoftCapInWei + ITOmainCapInWei;
   }
    /*
     * @dev finish crowdsale
     */
    function finishCrowdsale() onlyOwner public {
        require(now > ITOendTime || ITOwei == ITOhardCapInWei);
        require(!token.mintingFinished());

        if(ITOsoftCapReached()) {
            token.finishMinting(true);
        } else {
            refundAllowed = true;
            token.finishMinting(false);
        }
    }

    // @return true if crowdsale event has ended
    function running() constant public returns (bool) {
        return withinPeriod() && !token.mintingFinished();
    }
}