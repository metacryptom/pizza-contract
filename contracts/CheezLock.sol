// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "openzeppelin-latest/token/ERC20/utils/TokenTimelock.sol";
import "openzeppelin-latest/token/ERC20/IERC20.sol";
import "openzeppelin-latest/token/ERC20/utils/SafeERC20.sol";

import "openzeppelin-latest/access/Ownable.sol";


contract CheezLock is TokenTimelock {

    using SafeERC20 for IERC20;

    constructor (IERC20 token_, address beneficiary_, uint256 releaseTime_) public TokenTimelock(token_, beneficiary_, releaseTime_) {
    }


    /**
    * @notice Transfers tokens held by timelock to beneficiary.
    */
    function backUpRelease(IERC20 _token) public  {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= releaseTime(), "TokenTimelock: current time is before release time");

        uint256 amount = _token.balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to release");

        _token.safeTransfer(beneficiary(), amount);
    }
}