// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v4.9.3/contracts/proxy/utils/Initializable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v4.9.3/contracts/access/OwnableUpgradeable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v4.9.3/contracts/security/ReentrancyGuardUpgradeable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v4.9.3/contracts/token/ERC20/IERC20Upgradeable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/v4.9.3/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract PBTCStakingUpgradeable is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public pbtc;
    uint256 public rewardRate;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalStaked;
    uint256 public totalRewardPool;
    uint256 public lockDuration;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public lastStakeTime;
    mapping(address => bool) public whitelist;

    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "Not whitelisted");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address _pbtc,
        uint256 _startTime,
        uint256 _duration,
        uint256 _totalRewardPool
    ) public initializer {
        __Ownable_init();
        transferOwnership(initialOwner);
        __ReentrancyGuard_init();

        pbtc = IERC20Upgradeable(_pbtc);
        startTime = _startTime;
        endTime = _startTime + _duration;
        totalRewardPool = _totalRewardPool;
        rewardRate = _totalRewardPool / _duration;
        lastUpdateTime = _startTime;

        lockDuration = 7 days;
    }

    function setLockDuration(uint256 _duration) external onlyOwner {
        lockDuration = _duration;
    }

    function addToWhitelist(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whitelist[users[i]] = true;
        }
    }

    function removeFromWhitelist(address[] calldata users) external onlyOwner {
    for (uint256 i = 0; i < users.length; i++) {
        whitelist[users[i]] = false;
    }
}

    function stake(uint256 amount) external nonReentrant onlyWhitelisted updateReward(msg.sender) {
        require(block.timestamp >= startTime, "Staking not started");
        require(amount > 0, "Cannot stake 0");

        staked[msg.sender] += amount;
        totalStaked += amount;
        lastStakeTime[msg.sender] = block.timestamp;

        pbtc.safeTransferFrom(msg.sender, address(this), amount);
    }

    function claim() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards");
        rewards[msg.sender] = 0;
        pbtc.safeTransfer(msg.sender, reward);
    }

    function withdraw() public nonReentrant updateReward(msg.sender) {
        require(block.timestamp >= lastStakeTime[msg.sender] + lockDuration, "Withdraw locked");

        // Claim rewards first
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            pbtc.safeTransfer(msg.sender, reward);
        }

        // Then unstake
        uint256 amount = staked[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        staked[msg.sender] = 0;
        totalStaked -= amount;
        pbtc.safeTransfer(msg.sender, amount);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < endTime ? block.timestamp : endTime;
    }

    function earned(address account) public view returns (uint256) {
        return
            (staked[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) /
            1e18 + rewards[account];
    }

    // For UI
    function getStakedAmount(address account) external view returns (uint256) {
        return staked[account];
    }

    function getUnclaimedRewards(address account) external view returns (uint256) {
        return earned(account);
    }

    // Gap for upgradeable storage safety
    uint256[50] private __gap;
}

