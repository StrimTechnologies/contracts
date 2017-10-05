pragma solidity ^ 0.4 .11;

import "./ERC23StandardToken.sol";

// Based in part on code by Open-Zeppelin: https://github.com/OpenZeppelin/zeppelin-solidity.git
// Based in part on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol

// Based in part on code by Open-Zeppelin: https://github.com/OpenZeppelin/zeppelin-solidity.git
// Based in part on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol

contract STRIMToken is ERC23StandardToken {

    // metadata
    string public constant name = "STRIM Token";
    string public constant symbol = "STR";
    uint256 public constant decimals = 18;
    string public version = "1.0";
    bool public halted; //Halt crowdsale in emergency
    bool public isFinalized; // switched to true in operational state
    mapping(address => uint256) exchangeRate;
    uint256 public fundingStartBlock;
    uint256 public fundingEndBlock;
    uint256 public constant tokenExchangeRateMile1 = 3000; // 3000 STR tokens for the 1 eth at first phase
    uint256 public constant tokenExchangeRateMile2 = 2000; // 2000 STR tokens for the 1 eth at second phase
    uint256 public constant tokenExchangeRateMile3 = 1000; // 1000 STR tokens for the 1 eth at third phase   
    uint256 public constant tokenCreationMinMile1 = 10 * (10 ** 6) * 10 ** decimals; //minimum ammount of tokens to be created for the ICO to be succesfull
    uint256 public constant tokenCreationMinMile2 = 78 * (10 ** 6) * 10 ** decimals; //tokens to be created for the ICO for the second milestone 
    uint256 public constant tokenCreationMaxCap = 187 * (10 ** 6) * 10 ** decimals; //max tokens to be created

    // contracts
    address public ethFundDeposit; // deposit address for ETH for Strim Team
    address public strFundDeposit; // deposit address for Strim Team use and STR User Fund
    address public StrimTeam; //contract owner

    // events
    event LogRefund(address indexed _to, uint256 _value);
    event CreateSTR(address indexed _to, uint256 _value);
    event Halt(); //Halt event
    event Unhalt(); //Unhalt event

    modifier onlyTeam() {
        //only do if call is from owner modifier
        require(msg.sender == StrimTeam);
        _;
    }

    modifier crowdsaleTransferLock() {
        require(isFinalized);
        _;
    }

    modifier whenNotHalted() {
        // only do when not halted modifier
        require(!halted);
        _;
    }

    // constructor
    function STRIMToken(
        address _ethFundDeposit,
        address _strFundDeposit,
        uint256 _fundingStartBlock,
        uint256 _fundingEndBlock) {
        isFinalized = false; //controls pre through crowdsale state
        halted = false;
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
        require(!isFinalized);
        require(block.number >= fundingStartBlock);
        require(block.number <= fundingEndBlock);
		require (totalSupply < tokenCreationMaxCap);
        require(msg.value > 0);

        uint256 retRate = returnRate();

        uint256 tokens = msg.value.mul(retRate); //decimals=18, so no need to adjust for unit  
		exchangeRate[recipient]=retRate;
		
        balances[recipient] = balances[recipient].add(tokens);//map tokens to the reciepient address	
        totalSupply = totalSupply.add(tokens);

        CreateSTR(msg.sender, tokens); // logs token creation
        Transfer(this, recipient, tokens);
    }

    //Return rate of token against ether.
    function returnRate() public constant returns(uint256) {
        if (totalSupply < tokenCreationMinMile1) {
            return tokenExchangeRateMile1;
        } else if (totalSupply < tokenCreationMinMile2) {
            return tokenExchangeRateMile2;
        } else {
            return tokenExchangeRateMile3;  
        }
    }

    function finalize() external onlyTeam{
        require(!isFinalized);//check if already ran        
        require(totalSupply >= tokenCreationMinMile1); // have to sell minimum to move to operational
        require(block.number > fundingEndBlock || totalSupply >= tokenCreationMaxCap);//don't end before ico period ends or max cap reached

        uint256 strVal = totalSupply.div(2);
        balances[strFundDeposit] = strVal; // deposit Strim share
        CreateSTR(msg.sender, strVal); // logs token creation

        // move to operational        
        if (!ethFundDeposit.send(this.balance)) revert(); // send the eth to Strim Team
        if (!strFundDeposit.send(this.balance)) revert(); // send the str to Strim Team
        isFinalized = true;
    }

    // Allows contributors to recover their ether in the case of a failed funding campaign.
    function refund() external {
        require(!isFinalized); // prevents refund if operational
        require(block.number > fundingEndBlock); // prevents refund until sale period is over
        require(totalSupply < tokenCreationMinMile1); // no refunds if we sold enough
        require(msg.sender != strFundDeposit); // Strim not entitled to a refund
        
        if (exchangeRate[msg.sender] > 0) {  //presale ether is non refundable as it will be used for marketing during the ICO period
		    uint256 strVal = balances[msg.sender];
            balances[msg.sender] = 0; //if refunded delete the users tokens
            totalSupply = totalSupply.sub(strVal); // extra safe
       	    uint256 ethVal = strVal / exchangeRate[msg.sender]; // should be safe; considering it never reached the first milestone;
            LogRefund(msg.sender, ethVal); // log it 
            if (!msg.sender.send(ethVal)) revert(); // if you're using a contract; make sure it works with .send gas limits
		}
    }

    function transfer(address _to, uint256 _value, bytes _data) public crowdsaleTransferLock returns(bool success) {
        return super.transfer(_to, _value, _data);
    }

    function transfer(address _to, uint256 _value) public crowdsaleTransferLock {
        super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public crowdsaleTransferLock {
        super.transferFrom(_from, _to, _value);
    }
}
