// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPIZZAToken.sol";


contract PIZZAKeeper is Ownable {
    using SafeMath for uint256;

    struct PIZZAApplicatioin {
        address PIZZAMember; // Address of member
        uint256 perBlockLimit; //  
        uint256 transferedValue; //Total transferd 
        uint256 startBlock; // 
    } 


    // The PIZZA TOKEN!
    mapping(address => PIZZAApplicatioin) public applications;

    bool public appPublished ; //when published ,applications can not be modified
    uint256 public appPublishedBlock; //when published ,applications can not be modified
    uint256 public totalPerBlockLimit; //when published ,applications can not be modified
    uint256 public storeTotalMintedValue; 


    IPIZZAToken public immutable pizza;
    uint256 public immutable startMintedBlock;
    address public immutable devAddr; // 0.2
    address public immutable valutAddr;// 0.08


    event ApplicationAdded(address indexed PIZZAMember, uint256 perBlockLimit);
    event ApplicationPublished(address publisher,uint256 totalPerBlockLimit);

    event PIZZAForRequestor(address indexed to ,uint256 amount);

    
    modifier appNotPublished() {
        require(!appPublished, "PIZZASwapMining: app published");
        _;
    }

    modifier appShouldPublished() {
        require(appPublished, "PIZZASwapMining: app not published");
        _;
    }


    constructor(
        IPIZZAToken _pizza,
        address _devAddr,
        address _valutAddr,
        uint256 _startMintedBlock
    ) public {
        require(_devAddr != address(0));
        require(_valutAddr != address(0)); 
        require(address(_pizza) !=  address(0));

        pizza = _pizza;
        appPublished = false;
        devAddr = _devAddr;
        valutAddr = _valutAddr;

        startMintedBlock = _startMintedBlock;
    }


    function addApplication(address _PIZZAMember,uint256 _perBlockLimit) public onlyOwner appNotPublished {
        PIZZAApplicatioin storage app = applications[_PIZZAMember];
        app.PIZZAMember = _PIZZAMember;
        app.perBlockLimit = _perBlockLimit;
        app.startBlock = startMintedBlock;
        app.transferedValue = 0;
        totalPerBlockLimit = totalPerBlockLimit.add(_perBlockLimit);

        emit ApplicationAdded(_PIZZAMember,_perBlockLimit);
    }


    
    // can update perBlockLimit even after published,but totalPerBlockLimit must be the same
    // o(n2) to check if the addresses are unique, so the length of the array should not be too large
    function updateApplicationPerBlockLimit(address[] memory _PIZZAMembers , uint256[] memory  _perBlockLimits) public onlyOwner  {
        require(_PIZZAMembers.length == _perBlockLimits.length, "length not match");
        require(areAddressesUnique(_PIZZAMembers), "duplicate member");

        uint256 oldMembersPerBlockLimit  = 0;
        uint256 newSetTotalPerBlockLimit  = 0;

        for (uint256 i = 0; i < _PIZZAMembers.length; i++) {
            PIZZAApplicatioin storage app = applications[_PIZZAMembers[i]];
            // must exists
            require(app.PIZZAMember == _PIZZAMembers[i], "not PIZZA member");

            oldMembersPerBlockLimit = oldMembersPerBlockLimit.add(app.perBlockLimit);
            newSetTotalPerBlockLimit = newSetTotalPerBlockLimit.add(_perBlockLimits[i]);

            app.perBlockLimit = _perBlockLimits[i];
            //force update variable,although some tokens are not minted
            // if startMintedBlock  is not in the future
            if (startMintedBlock <= block.number){
                //reset transferedValue and started number
                app.transferedValue = 0;
                app.startBlock = block.number;
            }
        }
        require(oldMembersPerBlockLimit == newSetTotalPerBlockLimit, "totalPerBlockLimit not match");
    }


    // _startMintedBlock may be in the future ,or in the past
    function publishApplication() public onlyOwner appNotPublished {
        //update variable
        appPublished = true;
        appPublishedBlock = block.number;
        storeTotalMintedValue = 0;

        emit ApplicationPublished(msg.sender,totalPerBlockLimit);
    }
 

    // application can request multiple times for PIZZA
    function requestForPIZZA(uint256 _amount) public  appShouldPublished returns (uint256) {
        // when reward is zero,this should not revert because the swap methods still depend on this
        if(_amount == 0){
            return 0;
        }
        PIZZAApplicatioin storage app = applications[msg.sender];
        require( app.PIZZAMember == msg.sender  , "not PIZZA member"  );
        require(block.number > app.startBlock,"not start");


        // new added must not exceed totalPerBlockLimit
        // no revert 
        uint256 newTotalMintedValue =  storeTotalMintedValue.add(_amount);
        if(newTotalMintedValue > block.number.sub(startMintedBlock).mul(totalPerBlockLimit)){
            return 0;
        }


        //  _amount plus transferedValue must not exceed perBlockLimit * (block.number - startBlock)
        // no revert
        uint256 totalUnlockedValueForApp = block.number.sub(app.startBlock).mul(app.perBlockLimit);
        if (app.transferedValue.add(_amount) > totalUnlockedValueForApp){
            return 0;
        }


        // we can mint PIZZA to the requestor
        // when 1 PIZZA is mint , 0.20 send to team, 0.08  send to  vault.  0.72  send to rest applications (swap+stake)
        //mint to dev,valut
        pizza.mint(devAddr,_amount.mul(20).div(100));
        pizza.mint(valutAddr,_amount.mul(8).div(100));
        uint256 leftAmount = _amount.mul(72).div(100);

        if(!pizza.mint(msg.sender,leftAmount)){
            //PIZZA not enough
            leftAmount = 0;
        }
        
        //update  storage value
        app.startBlock = block.number;
        app.transferedValue = app.transferedValue.add(_amount);
        storeTotalMintedValue = newTotalMintedValue;

        emit PIZZAForRequestor(msg.sender, leftAmount);
        return leftAmount;
    }



    function getApplication(address _PIZZAMember) public view returns (uint256,uint256) {
        PIZZAApplicatioin storage app = applications[_PIZZAMember];
        return (app.perBlockLimit,app.startBlock);
    }



    // check if the addresses are unique
    function areAddressesUnique(address[] memory addresses) internal pure returns (bool) {
        for (uint i = 0; i < addresses.length; i++) {
            for (uint j = i + 1; j < addresses.length; j++) {
                if (addresses[i] == addresses[j]) {
                    return false;
                }
            }
        }
        return true;
    }

}
