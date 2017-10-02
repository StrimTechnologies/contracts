
pragma solidity ^0.4.11;

import "./ERC23StandardToken.sol";

// Based in part on code by Open-Zeppelin: https://github.com/OpenZeppelin/zeppelin-solidity.git
// Based in part on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol

contract STRIMToken is ERC23StandardToken {

    // metadata
    string public constant name = "STRIM Token";
    string public constant symbol = "STR";
    uint256 public constant decimals = 18;	
    string public version = "0.3";	
	bool public halted = false; //Halt crowdsale in emergency
   

    // contracts
    address public ethFundDeposit; // deposit address for ETH for Strim Team
    address public strFundDeposit; // deposit address for Strim Team use and STR User Fund
	address public StrimTeam; //contract owner


    bool public isFinalized; // switched to true in operational state    
    uint256 public fundingStartPresaleBlock;
	uint256 public fundingStartBlock;
    uint256 public fundingEndBlock;    
	uint256 public constant tokenExchangeRatePreSale = 10000; // 10000 STR tokens for 1 eth at the presale
    uint256 public constant tokenExchangeRateMile1 = 3000; // 3000 STR tokens for the 1 eth at first phase
    uint256 public constant tokenExchangeRateMile2 = 2000; // 2000 STR tokens for the 1 eth at second phase
    uint256 public constant tokenExchangeRateMile3 = 1000; // 1000 STR tokens for the 1 eth at third phase   
    uint256 public constant tokenCreationMinMile1 = 18 * (10**6) * 10**decimals; //minimum ammount of tokens to be created for the ICO to be succesfull
    uint256 public constant tokenCreationMinMile2 = 28 * (10**6) * 10**decimals; //tokens to be created for the ICO for the second milestone    


    // events
    event LogRefund(address indexed _to, uint256 _value);
    event CreateSTR(address indexed _to, uint256 _value);
	event Halt(); //Halt event
    event Unhalt(); //Unhalt event
	
	modifier onlyTeam() {
        //only do if call is from owner modifier
        require (msg.sender == StrimTeam);
        _;
    }
	
	modifier crowdsaleTransferLock() {       
        require (!isFinalized);
        _;
    }

    modifier whenNotHalted() {
        // only do when not halted modifier
        require (!halted);
        _;
    }

    // constructor
    function STRIMToken(
        address _ethFundDeposit,
        address _strFundDeposit,
        uint256 _fundingStartBlock,
        uint256 _fundingEndBlock) {
        isFinalized = false; //controls pre through crowdsale state
        ethFundDeposit = _ethFundDeposit;
        strFundDeposit = _strFundDeposit;
        fundingStartBlock = _fundingStartBlock;
        fundingEndBlock = _fundingEndBlock;
        totalSupply = 0;       
		StrimTeam = msg.sender;        
    }
	
	//Fallback function when receiving Ether.
    function() payable {
        buy();
    }
	
	 //Halt ICO in case of emergency.
    function halt() onlyTeam {
        halted = true;
        Halt();
    }

    function unhalt() onlyTeam {
        halted = false;
        Unhalt();
    }

    function buy() payable {
        createTokens(msg.sender);
    }
	
	

    //mint Tokens. Accepts ether and creates new STR tokens.
    function createTokens(address recipient) public payable whenNotHalted {
        require (!isFinalized);		
        require (block.number >= fundingStartBlock);
        require (block.number <= fundingEndBlock);
        require (msg.value > 0);
        
		uint256 tokens =  msg.value.mul(returnRate()); //decimals=18, so no need to adjust for unit      
		balances[recipient] = balances[recipient].add(tokens);
        totalSupply = totalSupply.add(tokens);

        
        CreateSTR(msg.sender, tokens); // logs token creation
		Transfer(this, recipient, tokens);
    }
	
	//Return rate of token against ether.
	function returnRate( ) public constant returns(uint256) { 
		if (block.number <(fundingStartBlock+10116)) {
			return tokenExchangeRatePreSale;
		} else if (totalSupply < tokenCreationMinMile1) {
            return tokenExchangeRateMile1;
        } else if (totalSupply < tokenCreationMinMile2){
			return tokenExchangeRateMile2;
		} else {
			return tokenExchangeRateMile3;
		}
    }		

    function finalize() external {
        require (!isFinalized);
        require (msg.sender == ethFundDeposit); // locks finalize to the ultimate ETH owner
        require (totalSupply >= tokenCreationMinMile1); // have to sell minimum to move to operational
        require (block.number <= fundingEndBlock);

        uint256 strVal = totalSupply.div (2);
        balances[strFundDeposit] = strVal; // Deposit Strim share
        CreateSTR(msg.sender, strVal); // logs token creation

        // move to operational        
        if (!ethFundDeposit.send(this.balance)) throw; // send the eth to Strim Team
		if (!strFundDeposit.send(this.balance)) throw; // send the eth to Strim Team
		isFinalized = true;
    }

    // Allows contributors to recover their ether in the case of a failed funding campaign.
    function refund() external {
        require (!isFinalized); // prevents refund if operational
        require (block.number >= fundingEndBlock); // prevents refund until sale period is over
        require (totalSupply < tokenCreationMinMile1); // no refunds if we sold enough
        require (msg.sender != strFundDeposit); // Strim not entitled to a refund
		require (strVal > 0);
        
		uint256 strVal = balances[msg.sender];       
        balances[msg.sender] = 0;
        totalSupply = totalSupply.sub(strVal); // extra safe
        uint256 ethVal = strVal / tokenExchangeRateMile1; // should be safe; considering it never reached the first milestone;
        LogRefund(msg.sender, ethVal); // log it 
        if (!msg.sender.send(ethVal)) throw; // if you're using a contract; make sure it works with .send gas limits
    }
	
	function transfer(address _to, uint256 _value, bytes _data) public crowdsaleTransferLock returns (bool success) {
        return super.transfer(_to, _value, _data);
    }

	function transfer(address _to, uint256 _value) public crowdsaleTransferLock {
        super.transfer(_to, _value);
	}

    function transferFrom(address _from, address _to, uint256 _value) public crowdsaleTransferLock {
        super.transferFrom(_from, _to, _value);
    }
}