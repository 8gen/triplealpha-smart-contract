pragma solidity ^0.4.18;

library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public constant returns (uint256 balance) {
    return balances[_owner];
  }

}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));

    uint256 _allowance = allowed[_from][msg.sender];

    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // require (_value <= _allowance);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  /**
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   */
  function increaseApproval (address _spender, uint _addedValue)
    returns (bool success) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function decreaseApproval (address _spender, uint _subtractedValue)
    returns (bool success) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}

contract MintableToken is StandardToken, Ownable {
  event Mint(address indexed to, uint256 amount);
  event MintFinished();

  bool public mintingFinished = false;


  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
    totalSupply = totalSupply.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    Mint(_to, _amount);
    Transfer(0x0, _to, _amount);
    return true;
  }

  /**
   * @dev Function to stop minting new tokens.
   * @return True if the operation was successful.
   */
  function finishMinting() onlyOwner public returns (bool) {
    mintingFinished = true;
    MintFinished();
    return true;
  }
}

contract MultiOwners {

    event AccessGrant(address indexed owner);
    event AccessRevoke(address indexed owner);
    
    mapping(address => bool) owners;
    address public publisher;


    function MultiOwners() {
        owners[msg.sender] = true;
        publisher = msg.sender;
    }

    modifier onlyOwner() { 
        require(owners[msg.sender] == true);
        _; 
    }

    function isOwner() constant returns (bool) {
        return owners[msg.sender] ? true : false;
    }

    function checkOwner(address maybe_owner) constant returns (bool) {
        return owners[maybe_owner] ? true : false;
    }


    function grant(address _owner) onlyOwner {
        owners[_owner] = true;
        AccessGrant(_owner);
    }

    function revoke(address _owner) onlyOwner {
        require(_owner != publisher);
        require(msg.sender != _owner);

        owners[_owner] = false;
        AccessRevoke(_owner);
    }
}

contract Haltable is MultiOwners {
    bool public halted;

    modifier stopInEmergency {
        require(!halted);
        _;
    }

    modifier onlyInEmergency {
        require(halted);
        _;
    }

    // called by the owner on emergency, triggers stopped state
    function halt() external onlyOwner {
        halted = true;
    }

    // called by the owner on end of emergency, returns to normal state
    function unhalt() external onlyOwner onlyInEmergency {
        halted = false;
    }

}

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
     * @param _at â new start date
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
     * @param _at â new start date
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

contract TripleAlphaToken is MintableToken {

    string public constant name = 'Triple Alpha Token';
    string public constant symbol = 'TRIA';
    uint8 public constant decimals = 18;
    bool public transferAllowed;

    event Burn(address indexed from, uint256 value);
    event TransferAllowed(bool);

    modifier canTransfer() {
        require(mintingFinished && transferAllowed);
        _;        
    }

    function transferFrom(address from, address to, uint256 value) canTransfer returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function transfer(address to, uint256 value) canTransfer returns (bool) {
        return super.transfer(to, value);
    }

    function finishMinting(bool _transferAllowed) onlyOwner returns (bool) {
        transferAllowed = _transferAllowed;
        TransferAllowed(_transferAllowed);
        return super.finishMinting();
    }

    function burn(address from) onlyOwner returns (bool) {
        Transfer(from, 0x0, balances[from]);
        Burn(from, balances[from]);

        balances[0x0] += balances[from];
        balances[from] = 0;
    }
}

