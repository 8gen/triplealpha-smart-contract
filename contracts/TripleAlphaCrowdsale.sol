pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './TripleAlphaToken.sol';
import './Haltable.sol';
import './MultiOwners.sol';


contract TripleAlphaCrowdsale is MultiOwners, Haltable {
    using SafeMath for uint256;

    // Global
    // ETHUSD change rate
    uint256 public rateETHUSD = 300e2;

    // minimal token selled per time
    uint256 public minimalTokens = 1e18;

    // Sale token
    TripleAlphaToken public token;

    // Withdraw wallet
    address public wallet;

    // Pre-ICO
    // Maximum possible cap in USD on phaseOne
    uint256 public phaseOneMainCapInUSD = 1000000e2;

    // Maximum possible cap in USD on phaseOne
    uint256 public phaseOneHardCapInUSD = phaseOneMainCapInUSD;

    uint256 public phaseOnePeriod = 14 days;

    // Token Price in USD
    uint256 public phaseOneTokenPriceUSD = 50;

    // WEI per token
    uint256 public phaseOneWeiPerToken = phaseOneTokenPriceUSD.mul(1 ether).div(rateETHUSD);
    
    // start and end timestamp where investments are allowed (both inclusive)
    uint256 public phaseOneStartTime;
    uint256 public phaseOneEndTime;

    // total wei received during phase one
    uint256 public phaseOneWei;

    // Maximum possible cap in wei for phase one
    uint256 public phaseOneMainCapInWei = phaseOneMainCapInUSD.mul(1 ether).div(rateETHUSD);
    // Maximum possible cap in wei
    uint256 public phaseOneHardCapInWei = phaseOneMainCapInWei;


    // ICO
    // Minimal possible cap in USD on phaseTwo
    uint256 public phaseTwoSoftCapInUSD = 1000000e2;

    // Maximum possible cap in USD on phaseTwo
    uint256 public phaseTwoMainCapInUSD = 8000000e2;

    uint256 public phaseTwoPeriod = 28 days;

    // Maximum possible cap in USD on phaseTwo
    uint256 public phaseTwoHardCapInUSD = phaseTwoSoftCapInUSD + phaseTwoMainCapInUSD;

    // Token Price in USD
    uint256 public phaseTwoTokenPriceUSD = 100;

    // WEI per token
    uint256 public phaseTwoWeiPerToken = phaseTwoTokenPriceUSD.mul(1 ether).div(rateETHUSD);

    // start and end timestamp where investments are allowed (both inclusive)
    uint256 public phaseTwoStartTime;
    uint256 public phaseTwoEndTime;

    // total wei received during phase two
    uint256 public phaseTwoWei;
    
    // refund if softCap is not reached
    bool public refundAllowed = false;

    // need for refund
    mapping(address => uint256) public received_ethers;


    // Hard possible cap - soft cap in wei for phase two
    uint256 public phaseTwoMainCapInWei = phaseTwoMainCapInUSD.mul(1 ether).div(rateETHUSD);

    // Soft cap in wei
    uint256 public phaseTwoSoftCapInWei = phaseTwoSoftCapInUSD.mul(1 ether).div(rateETHUSD);

    // Hard possible cap - soft cap in wei for phase two
    uint256 public phaseTwoHardCapInWei = phaseTwoSoftCapInWei + phaseTwoMainCapInWei;


    // Events
    event TokenPurchase(address indexed beneficiary, uint256 value, uint256 amount);
    event OddMoney(address indexed beneficiary, uint256 value);
    event SetPhaseOneStartTime(uint256 new_startTimePhaseOne);
    event SetPhaseTwoStartTime(uint256 new_startTimePhaseTwo);

    modifier validPurchase() {
        bool nonZeroPurchase = msg.value != 0;

        require(withinPeriod() && nonZeroPurchase);

        _;        
    }

    modifier isExpired() {
        require(now > phaseTwoEndTime);

        _;        
    }

    function withinPeriod () constant returns(bool res) {
        bool withinPhaseOne = (now >= phaseOneStartTime && now <= phaseOneEndTime);
        bool withinPhaseTwo = (now >= phaseTwoStartTime && now <= phaseTwoEndTime);
        return (withinPhaseOne || withinPhaseTwo);
    }
    


    function TripleAlphaCrowdsale(uint256 _phaseOneStartTime, uint256 _phaseTwoStartTime, address _wallet) {
        require(_phaseOneStartTime >= now);
        require(_phaseTwoStartTime > _phaseOneStartTime);
        require(_wallet != 0x0);

        token = new TripleAlphaToken();
        wallet = _wallet;

        setPhaseOneStartTime(_phaseOneStartTime);
        setPhaseTwoStartTime(_phaseTwoStartTime);
    }


    // @return current stage name
    function stageName() constant public returns (string) {
        bool beforePeriodPhaseOne = (now < phaseOneStartTime);
        bool withinPeriodPhaseOne = (now >= phaseOneStartTime && now <= phaseOneEndTime);
        bool betweenPeriodPhaseOneAndTwo = (now >= phaseOneEndTime && now <= phaseTwoStartTime);
        bool withinPeriodPhaseTwo = (now >= phaseTwoStartTime && now <= phaseTwoEndTime);

        if(beforePeriodPhaseOne) {
            return 'Not started';
        }

        if(withinPeriodPhaseOne) {
            return 'Pre-ITO';
        } 

        if(betweenPeriodPhaseOneAndTwo) {
            return 'Between Pre-ITO and ITO';
        }

        if(withinPeriodPhaseTwo) {
            return 'ITO';
        }

        return 'Finished';
    }

    function totalWei() public constant returns(uint256) {
        return phaseOneWei + phaseTwoWei;
    }
    
    function totalEther() public constant returns(uint256) {
        return totalWei().div(1e18);
    }

    /*
     * @dev set first phase start date
     * @param _at — new start date
     */
    function setPhaseOneStartTime(uint256 _at) onlyOwner {
        require(phaseOneStartTime == 0 || block.timestamp < phaseOneStartTime); // forbid change time when first phase is active
        require(block.timestamp < _at); // should be great than current block timestamp
        require(phaseTwoStartTime == 0 || _at < phaseTwoStartTime); // should be lower than start of second phase

        phaseOneStartTime = _at;
        phaseOneEndTime = phaseOneStartTime.add(phaseOnePeriod);
        SetPhaseOneStartTime(_at);
    }

    /*
     * @dev set second phase start date
     * @param _at — new start date
     */
    function setPhaseTwoStartTime(uint256 _at) onlyOwner {
        require(phaseTwoStartTime == 0 || block.timestamp < phaseTwoStartTime); // forbid change time when second phase is active
        require(block.timestamp < _at); // should be great than current block timestamp
        require(phaseOneEndTime < _at); // should be great than end first phase

        phaseTwoStartTime = _at;
        phaseTwoEndTime = phaseTwoStartTime.add(phaseTwoPeriod);
        SetPhaseTwoStartTime(_at);
    }

    function PhaseTwoSoftCapReached() internal returns (bool) {
        return phaseTwoWei >= phaseTwoSoftCapInWei;
    }

    /*
     * @dev fallback for processing ether
     */
    function() payable {
        return buyTokens(msg.sender);
    }

    function calcAmountAt(uint256 _value, uint256 _at) constant public returns (uint256, uint256) {
        uint256 estimate;
        uint256 odd;

        if(_at < phaseOneEndTime) {
            if(_value.add(phaseOneWei) > phaseOneHardCapInWei) {
                odd = _value.add(phaseOneWei).sub(phaseOneHardCapInWei);
                _value = phaseOneHardCapInWei.sub(phaseOneWei);
            } 
            estimate = _value.mul(1 ether).div(phaseOneWeiPerToken);
            require(_value + phaseOneWei <= phaseOneHardCapInWei);
        } else {
            if(_value.add(phaseTwoWei) > phaseTwoHardCapInWei) {
                odd = _value.add(phaseTwoWei).sub(phaseTwoHardCapInWei);
                _value = phaseTwoHardCapInWei.sub(phaseTwoWei);
            }             
            estimate = _value.mul(1 ether).div(phaseTwoWeiPerToken);
            require(_value + phaseTwoWei <= phaseTwoHardCapInWei);
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

        if(now < phaseOneEndTime) {
            // Pre-ITO
            phaseOneWei = phaseOneWei.add(msg.value);

        } else {
            // ITO
            if(PhaseTwoSoftCapReached()) {
                phaseTwoWei = phaseTwoWei.add(msg.value).sub(odd_ethers);
            } else if(this.balance >= phaseTwoSoftCapInWei) {
                phaseTwoWei = this.balance.sub(odd_ethers);
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

    // @refund to backers, if softCap is not reached
    function refund() isExpired public {
        require(refundAllowed);
        require(!PhaseTwoSoftCapReached());
        require(received_ethers[msg.sender] > 0);
        require(token.balanceOf(msg.sender) > 0);

        uint256 current_balance = received_ethers[msg.sender];
        received_ethers[msg.sender] = 0;
        token.burn(msg.sender);
        msg.sender.transfer(current_balance);
    }

    function finishCrowdsale() onlyOwner public {
        require(now > phaseTwoEndTime || phaseTwoWei == phaseTwoHardCapInWei);
        require(!token.mintingFinished());

        if(PhaseTwoSoftCapReached()) {
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