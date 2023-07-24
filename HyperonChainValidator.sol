//SPDX-License-Identifier: MIT
pragma solidity 0.8.19; 

interface ERC20Essential 
{
    function balanceOf(address user) external view returns(uint256);
    function transfer(address _to, uint256 _amount) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);
}


//*******************************************************************//
//------------------ Contract to Manage Ownership -------------------//
//*******************************************************************//
contract owned
{
    address public owner;
    address internal newOwner;
    mapping(address => bool) public signer;

    event OwnershipTransferred(address indexed _from, address indexed _to);
    event SignerUpdated(address indexed signer, bool indexed status);

    constructor() {
        owner = msg.sender;
        signer[msg.sender] = true;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlySigner {
        require(signer[msg.sender], 'caller must be signer');
        _;
    }

    function changeSigner(address _signer, bool _status) public onlyOwner {
        signer[_signer] = _status;
        emit SignerUpdated(_signer, _status);
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }

    //the reason for this flow is to protect owners from sending ownership to unintended address due to human error
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

    
//****************************************************************************//
//---------------------        MAIN CODE STARTS HERE     ---------------------//
//****************************************************************************//
    
contract HyperonChainValidator is owned {
    struct _validator
    {   
        uint _depositAmount;
        address _parentWallet;
        uint status;
    }

    mapping (address => _validator) validator;
    mapping(address => bool) blacklistValidator;
    mapping(address => bool) blacklistParent;

    uint activationAmount;
    uint fineAmount;
    address punishAccount;
    
    // This generates a public event of coin received by contract
    event SetPunishAccount(address oldPunishAccount, address newPunishAccount);
    event SetActivationAmount(uint oldActivationAmount, uint newActivationAmount);
    event SetFineAmount(uint oldFineAmount, uint newFineAmount);
    event BlackListValidator(address _blacklistWalletAddress);
    event BlackListParent(address _blacklistWalletAddress);
    event ValidatorAdded(address validatorAddress, address validatorParent, uint lockedAmount);
    event ValidatorRemoved(address validatorAddress, address validatorParent, uint releasedAmount);
    event ValidatorPunished(address validatorAddress, address validatorParent, uint releasedAmount, uint finedAmount);

    function setPunishAccount(address _punishAccount) external  onlyOwner returns(bool){
        require(_punishAccount != address(0), "0x Account Not Allowed");
        address _oldPunishAccount = punishAccount;
        punishAccount = _punishAccount;
        emit SetPunishAccount(_oldPunishAccount, punishAccount);
        return  true;
    }

    function setFineAmount(uint _fineAmount) external  onlyOwner returns(bool){
        require(_fineAmount <= 100, "Fine Amount Percentage Must Be Less Than Equal To 100");
        uint _oldFineAmount = fineAmount;
        fineAmount = _fineAmount;
        emit SetFineAmount(_oldFineAmount, fineAmount);
        return  true;
    }

    function setActivationAmount(uint _amount) external onlyOwner returns(bool){
        uint _oldActivationAmount = activationAmount;
        activationAmount = _amount;
        emit SetActivationAmount(_oldActivationAmount, activationAmount);
        return true;
    }

    function blackListValidator(address _blacklistWallet, bool status) external onlySigner returns(bool){
        require(_blacklistWallet != address(0), "0x Account Not Allowed");
        require(blacklistValidator[_blacklistWallet] != status, "BlackList Status Is Already Set For Validator");
        blacklistValidator[_blacklistWallet] = status;
        emit BlackListValidator(_blacklistWallet);
        return true;
    }

    function blackListParent(address _blacklistWallet, bool status) external onlySigner returns(bool){
        require(_blacklistWallet != address(0), "0x Account Not Allowed");
        require(blacklistParent[_blacklistWallet] != status, "BlackList Status Is Already Set For Parent");
        blacklistParent[_blacklistWallet] = status;
        emit BlackListParent(_blacklistWallet);
        return true;
    }

    function addValidator(address _validatorAddress) external payable returns(bool){
        require(_validatorAddress != address(0), "0x Account Not Allowed");
        require(blacklistParent[msg.sender] != true, "Parent Wallet Is BlackListed");
        require(blacklistValidator[_validatorAddress] != true, "Validator Wallet Is BlackListed");
        require(validator[_validatorAddress]._parentWallet == address(0), "0x Account Not Allowed");
        require(validator[_validatorAddress]._depositAmount == 0, "Validator Is Already Active");
        require(validator[_validatorAddress].status == 0, "Validator Status Is Already Active");
        require(msg.value == activationAmount, "Activation Amount Is Not Matching");

        validator[_validatorAddress]._depositAmount = msg.value;
        validator[_validatorAddress]._parentWallet = msg.sender;
        validator[_validatorAddress].status = 1;

        emit ValidatorAdded(_validatorAddress, validator[_validatorAddress]._parentWallet, validator[_validatorAddress]._depositAmount);

        return true;
    }

    function removeValidator(address _validatorAddress) external payable returns(bool){
        require(_validatorAddress != address(0), "0x Account Not Allowed");
        require(validator[_validatorAddress]._parentWallet == msg.sender, "Signer Must Be Parent Of Validator");
        require(validator[_validatorAddress].status == 1, "Validator Doesn't Exist");

        emit ValidatorRemoved(_validatorAddress, validator[_validatorAddress]._parentWallet, validator[_validatorAddress]._depositAmount);

        validator[_validatorAddress]._depositAmount = 0;
        validator[_validatorAddress]._parentWallet = address(0);
        validator[_validatorAddress].status = 0;

        return true;
    }

    function punishValidator(address _validatorAddress) external onlySigner returns(bool){
        require(_validatorAddress != address(0), "0x Account Not Allowed");
        require(validator[_validatorAddress]._parentWallet != address(0), "0x Account Not Allowed");
        require(validator[_validatorAddress].status == 1, "Validator Doesn't Exist");

        uint _finedAmount =0;
        if (fineAmount != 0){
            _finedAmount = (validator[_validatorAddress]._depositAmount * fineAmount)/100;
        }
        
        payable(validator[_validatorAddress]._parentWallet).transfer((validator[_validatorAddress]._depositAmount - _finedAmount));
        payable(punishAccount).transfer(_finedAmount);

        emit ValidatorPunished(_validatorAddress, validator[_validatorAddress]._parentWallet, (validator[_validatorAddress]._depositAmount-_finedAmount),_finedAmount);

        validator[_validatorAddress]._depositAmount = 0;
        validator[_validatorAddress]._parentWallet = address(0);
        validator[_validatorAddress].status = 0;

        return true;
    }

    receive () external payable {
    
    }

    function checkContract(address addr) public view returns (bool) {
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;  //keccak256 empty data hash                                                                              
        bytes32 codehash;
        assembly {
            codehash := extcodehash(addr)
        }
        return (codehash != 0x0 && codehash != accountHash);
    }

    function transferAsset(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        if (tokenAddress != address(0)){
            return ERC20Essential(tokenAddress).transfer(msg.sender, tokens);
        }
        else{
            payable(msg.sender).transfer(tokens);
            return true;
        }       
    }
}
