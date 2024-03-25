// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "openzeppelin-latest/token/ERC20/ERC20.sol";
import "openzeppelin-latest/access/Ownable.sol";


// Pizzatoken
contract PIZZAToken is ERC20("PIZZAToken", "PIZZA"), Ownable {

  uint256 constant TOTAL_SUPPLAY =  (5*10 ** 8) * (10 ** 18) ;  // 500 milli

  // mint with max supply
  // no error if over max supply , just return false
  function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
      if (_amount + totalSupply() > TOTAL_SUPPLAY) {
          return false;
      }
      _mint(_to, _amount);
      return true;
  }

}
