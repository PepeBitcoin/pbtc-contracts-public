
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PBTCPresale is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public pbtc;
    IERC20 public usdt;
    address public treasury;

    uint256 public constant PBTC_PER_USD = 1000; // $0.001 per PBTC
    uint256 public constant MAX_PER_WALLET = 1000 * 1e6; // $1000 in USDT (6 decimals)
    uint256 public hardcap; // e.g., 20000 * 1e6 for $20k
    uint256 public totalRaised;

    mapping(address => uint256) public contributed;

    bool public presaleOpen;

    event Purchased(address indexed user, uint256 usdtAmount, uint256 pbtcAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address _pbtc,
        address _usdt,
        address _treasury,
        uint256 _hardcap
    ) public initializer {
        __Ownable_init(initialOwner);
        transferOwnership(initialOwner);

        pbtc = IERC20(_pbtc);
        usdt = IERC20(_usdt);
        treasury = _treasury;
        hardcap = _hardcap;
        presaleOpen = true;
    }

    function setPresaleOpen(bool open) external onlyOwner {
        presaleOpen = open;
    }

    function buyWithUSDT(uint256 amount) external {
        require(presaleOpen, "Presale closed");
        require(amount > 0, "Amount must be > 0");

        uint256 newTotal = contributed[msg.sender] + amount;
        require(newTotal <= MAX_PER_WALLET, "Exceeds per-wallet cap");
        require(totalRaised + amount <= hardcap, "Hardcap reached");

        contributed[msg.sender] = newTotal;
        totalRaised += amount;

        usdt.safeTransferFrom(msg.sender, treasury, amount);

        uint256 pbtcAmount = amount * PBTC_PER_USD; // assumes PBTC is 18 decimals
        pbtc.safeTransfer(msg.sender, pbtcAmount * 1e12); // convert from 6 to 18 decimals

        emit Purchased(msg.sender, amount, pbtcAmount * 1e12);
    }
}

