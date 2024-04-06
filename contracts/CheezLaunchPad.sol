// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "openzeppelin-latest/token/ERC20/ERC20.sol";
import "openzeppelin-latest/access/Ownable.sol";




contract CHEEZLaunchPad is ERC20("CHEEZToken", "CHEEZ"), Ownable {

    //lanchpad const params
    uint256 constant TOTAL_SUPPLAY = 21000000 ether; // 
    uint256 constant MINUM_PARTICIPATE_AMOUNT =  0.001 ether;
    //TODO:change back to 2
    uint256 constant MAX_PARTICIPATE_AMOUNT_PER_ADDRESS =  200 ether;
    uint256 constant MAX_TOTAL_CONTRIBUTION = 200 ether; //

    //lanchpad config
    IERC20  immutable public mBTC;
    uint256 immutable public  startTime;
    uint256 immutable public endTime;

    //storage variables
    uint256 public totalContribution;
    bool public withdrawStarted = false;
    bool public distributed = false;

    mapping(address => uint256) public contributions;
    mapping(address => bool) public claimed;

    event Contributed(address contributor, uint256 amount);
    event Claimed(address contributor, uint256 amount);
    event Log(string msgtype, uint256 value);

    constructor(address _mBTC, uint256 _startTime, uint256 _endTime) {
        require(_endTime > _startTime, "End time must be after start time.");
        mBTC = IERC20(_mBTC);
        startTime = _startTime;
        endTime = _endTime;

        _mint(address(this), TOTAL_SUPPLAY);
    }

    function contribute(uint256 _amount) external {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Not within the contribution period.");
        require(totalContribution < MAX_TOTAL_CONTRIBUTION, "Contribution limit reached.");
        require(_amount >= MINUM_PARTICIPATE_AMOUNT && (contributions[msg.sender] + _amount) <= MAX_PARTICIPATE_AMOUNT_PER_ADDRESS, "Contribution amount invalid.");

        uint256 contributingAmount = _amount;
        if(totalContribution + _amount > MAX_TOTAL_CONTRIBUTION) {
            contributingAmount = MAX_TOTAL_CONTRIBUTION - totalContribution;
        }


        //do transfer
        mBTC.transferFrom(msg.sender, address(this), contributingAmount);
        //update variables
        contributions[msg.sender] += contributingAmount;
        totalContribution += contributingAmount;
        //emit event
        emit Contributed(msg.sender, contributingAmount);
    }

    function claim() external {
        require(withdrawStarted, "Withdraw not started.");
        require(!claimed[msg.sender], "Already claimed.");

        (,uint256 restAmounts) = _getShareAmounts();
        uint256 contributorTokens = restAmounts * contributions[msg.sender] / totalContribution;

        claimed[msg.sender] = true;
        this.transfer(msg.sender, contributorTokens);
        emit Claimed(msg.sender,contributorTokens);
    }


    function isEventEnded() external view returns(bool) {
        return _isEventEnded();
    }



    function getShareAmounts() external view returns(uint256 adminAmounts,uint256 restAmounts) {
        return _getShareAmounts();
    }



    // admin functions
    function mintAndDistribute() external onlyOwner {
        require(_isEventEnded(), "Contribution not finished.");
        require(!distributed, "Can only distributed once.");

        (uint256 adminAmounts,) = _getShareAmounts(); 

        //tranfer tokens
 //       emit Log("balanceOf", balanceOf(address(this)));

//        emit Log("adminAmounts", adminAmounts);
        this.transfer(msg.sender, adminAmounts);
        mBTC.transfer(msg.sender, totalContribution);
        
        distributed = true;
    }

    function setWithdrawStarted(bool _withdrawStarted) external onlyOwner {
        require(distributed, "Can only start withdraw after distribution.");
        withdrawStarted = _withdrawStarted;
    }



    function _isEventEnded() internal view returns(bool) {
        return block.timestamp > endTime || totalContribution >= MAX_TOTAL_CONTRIBUTION;
    }

    function _getShareAmounts() internal pure returns(uint256 adminAmounts,uint256 restAmounts) {
        adminAmounts = TOTAL_SUPPLAY / 100 * 55 ;   // 0.45 + 0.1
        restAmounts = TOTAL_SUPPLAY - adminAmounts;  //0.45
    }

   
}
