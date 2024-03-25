// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPIZZAToken.sol";
import "./HalfAttenuationPIZZAReward.sol";




interface IPIZZAKeeper {
  //PIZZAkeeper is in charge of the PIZZA
  //It control the speed of PIZZA release by rules 
  function requestForPIZZA(uint256 amount) external returns (uint256);
}


// PIZZAPark is interesting place where you can get more PIZZA as long as you stake
// Have fun reading it. Hopefully it's bug-free. God bless.

contract PIZZAPark is Ownable ,HalfAttenuationPIZZAReward,ReentrancyGuard{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Zos
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accPIZZAPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accPIZZAPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. PIZZAs to distribute per block.
        uint256 lastRewardBlock; // Last block number that PIZZAs distribution occurs.
        uint256 accPIZZAPerShare; // Accumulated PIZZAs per share, times 1e12. See below.
    }
    // The PIZZA TOKEN!
    IPIZZAToken public pizza;
    // The PIZZA Keeper
    IPIZZAKeeper public pizzakeeper;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        IPIZZAToken _pizza,
        IPIZZAKeeper _pizzakeeper,
        uint256 _pizzaPerBlock,
        uint256 _startBlock,
        uint256 _blockNumberOfHalfAttenuationCycle
    ) public HalfAttenuationPIZZAReward(_pizzaPerBlock,_startBlock,_blockNumberOfHalfAttenuationCycle){
        require(address(_pizza) != address(0));
        require(address(_pizzakeeper) != address(0));

        pizza = _pizza;
        pizzakeeper = _pizzakeeper;
        pizzaPerBlock = _pizzaPerBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPIZZAPerShare: 0
            })
        );
    }

    // Update the given pool's PIZZA allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function forceSetPizzaPerBlock(uint256 _newPizzaPerBlock, bool _withUpdate) public onlyOwner{
        if (_withUpdate) {
            massUpdatePools();
        }
        pizzaPerBlock = _newPizzaPerBlock;
    }

    // View function to see pending PIZZAs on frontend.
    function pendingPIZZA(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPIZZAPerShare = pool.accPIZZAPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 pizzaReward =
                getPIZZABetweenBlocks(pool.lastRewardBlock, block.number).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accPIZZAPerShare = accPIZZAPerShare.add(
                pizzaReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accPIZZAPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 pizzaReward = getPIZZABetweenBlocks(pool.lastRewardBlock, block.number).mul(pool.allocPoint).div(
                totalAllocPoint
            );

        pizzaReward = pizzakeeper.requestForPIZZA(pizzaReward);

        pool.accPIZZAPerShare = pool.accPIZZAPerShare.add(
            pizzaReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to PIZZAPark for PIZZA allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant{
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accPIZZAPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            safePIZZATransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accPIZZAPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant{
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accPIZZAPerShare).div(1e12).sub(
                user.rewardDebt
            );
        safePIZZATransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accPIZZAPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant{
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe pizza transfer function, just in case if rounding error causes pool to not have enough PIZZAs.
    function safePIZZATransfer(address _to, uint256 _amount) internal {
        uint256 pizzaBal = pizza.balanceOf(address(this));
        if (_amount > pizzaBal) {
            pizza.transfer(_to, pizzaBal);
        } else {
            pizza.transfer(_to, _amount);
        }
    }
}
