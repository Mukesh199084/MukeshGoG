// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title MetaVault Protocol
 * @notice A modular vault allowing users to deposit assets,
 *         receive shares, and earn yield via strategy contracts.
 * @dev This is a template. Extend and customize before production use.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function totalAssets() external view returns (uint256);
}

contract MetaVaultProtocol {
    // ------------------------------------------------------
    // EVENTS
    // ------------------------------------------------------
    event Deposit(address indexed user, uint256 amount, uint256 sharesMinted);
    event Withdraw(address indexed user, uint256 amount, uint256 sharesBurned);
    event StrategyUpdated(address indexed newStrategy);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    // ------------------------------------------------------
    // STORAGE
    // ------------------------------------------------------
    IERC20 public immutable asset;          // e.g., USDC, DAI
    IStrategy public strategy;              // Strategy contract
    address public owner;
    bool public paused;

    uint256 public totalShares;
    mapping(address => uint256) public shareBalance;

    // ------------------------------------------------------
    // MODIFIERS
    // ------------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Paused");
        _;
    }

    // ------------------------------------------------------
    // CONSTRUCTOR
    // ------------------------------------------------------
    constructor(address _asset) {
        require(_asset != address(0), "Invalid asset");
        asset = IERC20(_asset);
        owner = msg.sender;
    }

    // ------------------------------------------------------
    // VIEW FUNCTIONS
    // ------------------------------------------------------
    function totalAssets() public view returns (uint256) {
        uint256 vaultBalance = asset.balanceOf(address(this));
        uint256 strategyBalance = strategy.totalAssets();
        return vaultBalance + strategyBalance;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return (totalShares == 0) ? assets : (assets * totalShares / totalAssets());
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return (totalShares == 0) ? shares : (shares * totalAssets() / totalShares);
    }

    // ------------------------------------------------------
    // CORE VAULT LOGIC
    // ------------------------------------------------------
    function deposit(uint256 amount) external notPaused returns (uint256 shares) {
        require(amount > 0, "Amount = 0");

        // Pull tokens
        asset.transferFrom(msg.sender, address(this), amount);

        // Mint shares
        shares = convertToShares(amount);
        totalShares += shares;
        shareBalance[msg.sender] += shares;

        emit Deposit(msg.sender, amount, shares);

        // Optionally auto-deposit into strategy
        if (address(strategy) != address(0)) {
            asset.approve(address(strategy), amount);
            strategy.deposit(amount);
        }
    }

    function withdraw(uint256 shares) external notPaused returns (uint256 assetsOut) {
        require(shares > 0, "Shares = 0");
        require(shareBalance[msg.sender] >= shares, "Not enough shares");

        assetsOut = convertToAssets(shares);

        // Burn shares
        totalShares -= shares;
        shareBalance[msg.sender] -= shares;

        emit Withdraw(msg.sender, assetsOut, shares);

        // If assets are in strategy, withdraw them
        uint256 vaultBalance = asset.balanceOf(address(this));
        if (vaultBalance < assetsOut) {
            uint256 needed = assetsOut - vaultBalance;
            strategy.withdraw(needed);
        }

        asset.transfer(msg.sender, assetsOut);
    }

    // ------------------------------------------------------
    // OWNER FUNCTIONS
    // ------------------------------------------------------
    function setStrategy(address _strategy) external onlyOwner {
        require(_strategy != address(0), "Invalid strategy");
        strategy = IStrategy(_strategy);
        emit StrategyUpdated(_strategy);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) emit Paused(msg.sender);
        else emit Unpaused(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero addr");
        owner = newOwner;
    }
}
