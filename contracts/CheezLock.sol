// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "openzeppelin-latest/token/ERC20/utils/TokenTimelock.sol";
import "openzeppelin-latest/access/Ownable.sol";


contract CheezLock is TokenTimelock {
    constructor (IERC20 token_, address beneficiary_, uint256 releaseTime_) public TokenTimelock(token_, beneficiary_, releaseTime_) {
    }
}