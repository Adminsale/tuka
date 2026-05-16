pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FeeVault is ERC4626Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public totalFeesCollected;
    uint256 public constant MIN_DEPOSIT = 10;

    event FeesDeposited(uint256 amount);
    event FeesWithdrawn(uint256 amount);

    error BelowMinimumDeposit();

    constructor() {
        _disableInitializers();
    }

    function initialize(address _asset, address _admin) external initializer {
        __ERC4626_init(IERC20(_asset));
        __ERC20_init("Prediction Market Fee Vault", "pmFEE");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
    }

    function depositFees(uint256 amount) external {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        totalFeesCollected += amount;
        emit FeesDeposited(amount);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        if (assets < MIN_DEPOSIT) revert BelowMinimumDeposit();
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override returns (uint256) {
        uint256 assets = previewMint(shares);
        if (assets < MIN_DEPOSIT) revert BelowMinimumDeposit();
        return super.mint(shares, receiver);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
