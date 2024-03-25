// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";




contract HalfAttenuationPIZZAReward {
    using SafeMath for uint256;

    // The block number when PIZZA mining starts
    uint256 public startBlock;
    // The block number of half cycle
    uint256 public  blockNumberOfHalfAttenuationCycle;
      // PIZZA tokens created per block.
    uint256 public pizzaPerBlock;


     constructor(
        uint256 _pizzaPerBlock,
        uint256 _startBlock,
        uint256 _blockNumberOfHalfAttenuationCycle
    ) public {
        pizzaPerBlock = _pizzaPerBlock;
        startBlock = _startBlock;
        blockNumberOfHalfAttenuationCycle = _blockNumberOfHalfAttenuationCycle;
    }

    // Return reward multiplier over the given _from to _to block.
    function getPIZZABetweenBlocks(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return _getPIZZAFromStartblock(startBlock,blockNumberOfHalfAttenuationCycle,pizzaPerBlock,_to).sub( _getPIZZAFromStartblock(startBlock,blockNumberOfHalfAttenuationCycle,pizzaPerBlock,_from));
    }


    //for test
    function getPIZZAFromStartblock(uint256 _startBlock,uint256 _blockNumberOfHalfAttenuationCycle, uint256 _pizzaPerBlock,uint256 _to)
        public
        view
        returns (uint256)
    {
        return _getPIZZAFromStartblock(_startBlock,_blockNumberOfHalfAttenuationCycle,_pizzaPerBlock,_to);
    }



    function _getPIZZAFromStartblock(uint256 _startBlock,uint256 _blockNumberOfHalfAttenuationCycle,uint256 _pizzaPerBlock, uint256 _to)
        internal
        pure
        returns (uint256)
    {
        uint256 cycle = _to.sub(_startBlock).div(_blockNumberOfHalfAttenuationCycle);
        if(cycle > 255){
            cycle =  255;
        }
        uint256 attenuationMul =  1 << cycle;

        return _pizzaPerBlock.mul(_blockNumberOfHalfAttenuationCycle.mul(2)).sub(_pizzaPerBlock.mul(_blockNumberOfHalfAttenuationCycle).div(attenuationMul)).sub(    
            _blockNumberOfHalfAttenuationCycle.sub( _to.sub(_startBlock).mod(_blockNumberOfHalfAttenuationCycle) ).mul(_pizzaPerBlock).div(attenuationMul)
          );
    }




}

