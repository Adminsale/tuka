pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../tokens/OutcomeToken.sol";
import "../oracles/ChainlinkPriceFeed.sol";
import "../libraries/Math.sol";

contract PredictionMarket is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant RESOLVER_ROLE = keccak256("RESOLVER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    string public question;
    uint256 public resolutionTime;
    uint256 public disputeWindow;
    OutcomeToken public outcomeToken;
    uint256 public outcomeIdYes;
    uint256 public outcomeIdNo;
    IERC20 public baseToken;
    uint16 public feeBps;
    address public feeVault;
    ChainlinkPriceFeed public priceFeed;

    uint256 public reserveYes;
    uint256 public reserveNo;
    uint256 public totalLpShares;
    mapping(address => uint256) public lpShares;

    bool public resolved;
    uint8 public winner;
    uint256 public disputeEnd;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_FEE_BPS = 1000;

    event TokensPurchased(address indexed buyer, uint8 outcome, uint256 amountIn, uint256 amountOut);
    event TokensSold(address indexed seller, uint8 outcome, uint256 amountIn, uint256 amountOut);
    event LiquidityAdded(address indexed lp, uint256 amountYes, uint256 amountNo, uint256 shares);
    event LiquidityRemoved(address indexed lp, uint256 shares, uint256 amountYes, uint256 amountNo);
    event MarketResolved(uint8 winner, uint256 timestamp);
    event Redeemed(address indexed user, uint8 outcome, uint256 amount);
    event DisputeRaised(address indexed disputer);

    modifier whenNotResolved() {
        if (resolved) revert AlreadyResolved();
        _;
    }

    modifier whenResolved() {
        if (!resolved) revert NotResolved();
        _;
    }

    error AlreadyResolved();
    error NotResolved();
    error InvalidOutcome();
    error ZeroAmount();
    error TradingEnded();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error DisputeWindowClosed();
    error NotResolvedYet();
    error NoTokensToRedeem();
    error NothingToRedeem();
    error InsufficientShares();
    error FeeTooHigh();

    constructor(
        string memory _question,
        uint256 _resolutionTime,
        uint256 _disputeWindow,
        address _outcomeToken,
        uint256 _outcomeIdYes,
        uint256 _outcomeIdNo,
        address _baseToken,
        uint16 _feeBps,
        address _feeVault,
        address _priceFeed,
        address _resolver
    ) {
        if (_feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        question = _question;
        resolutionTime = _resolutionTime;
        disputeWindow = _disputeWindow;
        outcomeToken = OutcomeToken(_outcomeToken);
        outcomeIdYes = _outcomeIdYes;
        outcomeIdNo = _outcomeIdNo;
        baseToken = IERC20(_baseToken);
        feeBps = _feeBps;
        feeVault = _feeVault;
        priceFeed = ChainlinkPriceFeed(_priceFeed);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RESOLVER_ROLE, _resolver);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    function splitBase(uint256 amount) external whenNotResolved nonReentrant {
        if (amount == 0) revert ZeroAmount();
        baseToken.safeTransferFrom(msg.sender, address(this), amount);
        outcomeToken.mint(msg.sender, outcomeIdYes, amount, "");
        outcomeToken.mint(msg.sender, outcomeIdNo, amount, "");
    }

    function mergeOutcomes(uint256 amount) external whenNotResolved nonReentrant {
        if (amount == 0) revert ZeroAmount();
        outcomeToken.burn(msg.sender, outcomeIdYes, amount);
        outcomeToken.burn(msg.sender, outcomeIdNo, amount);
        baseToken.safeTransfer(msg.sender, amount);
    }

    function swap(uint256 tokenIn, uint256 tokenOut, uint256 amountIn, uint256 minAmountOut)
        external whenNotResolved nonReentrant returns (uint256)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert("Same token");
        if (block.timestamp >= resolutionTime) revert TradingEnded();
        require(
            (tokenIn == outcomeIdYes && tokenOut == outcomeIdNo) ||
            (tokenIn == outcomeIdNo && tokenOut == outcomeIdYes),
            "Invalid tokens"
        );

        outcomeToken.burn(msg.sender, tokenIn, amountIn);

        uint256 fee = (amountIn * feeBps) / BPS;
        uint256 amountAfterFee = amountIn - fee;
        _sendFees(fee);

        uint256 amountOut;
        bool buyingYes = (tokenIn == outcomeIdNo && tokenOut == outcomeIdYes);

        if (buyingYes) {
            amountOut = _getAmountOut(amountAfterFee, reserveNo, reserveYes);
            reserveNo += amountAfterFee;
            reserveYes -= amountOut;
        } else {
            amountOut = _getAmountOut(amountAfterFee, reserveYes, reserveNo);
            reserveYes += amountAfterFee;
            reserveNo -= amountOut;
        }

        if (amountOut < minAmountOut) revert SlippageExceeded();
        outcomeToken.mint(msg.sender, tokenOut, amountOut, "");

        emit TokensPurchased(msg.sender, buyingYes ? 1 : 2, amountIn, amountOut);
        return amountOut;
    }

    function buyOutcome(uint8 outcome, uint256 amountIn, uint256 minOut)
        external whenNotResolved nonReentrant returns (uint256)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (outcome != 1 && outcome != 2) revert InvalidOutcome();
        if (block.timestamp >= resolutionTime) revert TradingEnded();

        baseToken.safeTransferFrom(msg.sender, address(this), amountIn);
        outcomeToken.mint(msg.sender, outcomeIdYes, amountIn, "");
        outcomeToken.mint(msg.sender, outcomeIdNo, amountIn, "");

        uint256 toSwap = amountIn;
        if (outcome == 1) {
            outcomeToken.burn(msg.sender, outcomeIdNo, amountIn);
            uint256 fee = (amountIn * feeBps) / BPS;
            uint256 afterFee = amountIn - fee;
            _sendFees(fee);
            uint256 yesOut = _getAmountOut(afterFee, reserveNo, reserveYes);
            reserveNo += afterFee;
            reserveYes -= yesOut;
            outcomeToken.mint(msg.sender, outcomeIdYes, yesOut, "");
            if (amountIn + yesOut < minOut) revert SlippageExceeded();
            emit TokensPurchased(msg.sender, 1, amountIn, amountIn + yesOut);
            return amountIn + yesOut;
        } else {
            outcomeToken.burn(msg.sender, outcomeIdYes, amountIn);
            uint256 fee = (amountIn * feeBps) / BPS;
            uint256 afterFee = amountIn - fee;
            _sendFees(fee);
            uint256 noOut = _getAmountOut(afterFee, reserveYes, reserveNo);
            reserveYes += afterFee;
            reserveNo -= noOut;
            outcomeToken.mint(msg.sender, outcomeIdNo, noOut, "");
            if (amountIn + noOut < minOut) revert SlippageExceeded();
            emit TokensPurchased(msg.sender, 2, amountIn, amountIn + noOut);
            return amountIn + noOut;
        }
    }

    function sellOutcome(uint8 outcome, uint256 amountIn, uint256 minOut)
        external whenNotResolved nonReentrant returns (uint256)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (outcome != 1 && outcome != 2) revert InvalidOutcome();

        uint256 tokenId = outcome == 1 ? outcomeIdYes : outcomeIdNo;
        uint256 otherId = outcome == 1 ? outcomeIdNo : outcomeIdYes;
        outcomeToken.burn(msg.sender, tokenId, amountIn);

        uint256 fee = (amountIn * feeBps) / BPS;
        uint256 afterFee = amountIn - fee;
        _sendFees(fee);

        uint256 otherOut;
        if (outcome == 1) {
            otherOut = _getAmountOut(afterFee, reserveYes, reserveNo);
            reserveYes -= afterFee;
            reserveNo += otherOut;
        } else {
            otherOut = _getAmountOut(afterFee, reserveNo, reserveYes);
            reserveNo -= afterFee;
            reserveYes += otherOut;
        }

        outcomeToken.mint(msg.sender, otherId, otherOut, "");

        emit TokensSold(msg.sender, outcome, amountIn, otherOut);
        return otherOut;
    }

    function addLiquidity(uint256 amountBase)
        external whenNotResolved nonReentrant returns (uint256 shares)
    {
        if (amountBase == 0) revert ZeroAmount();
        if (block.timestamp >= resolutionTime) revert TradingEnded();

        baseToken.safeTransferFrom(msg.sender, address(this), amountBase);
        outcomeToken.mint(address(this), outcomeIdYes, amountBase, "");
        outcomeToken.mint(address(this), outcomeIdNo, amountBase, "");

        if (totalLpShares == 0) {
            shares = PredictionMath.sqrt(amountBase * amountBase) - MINIMUM_LIQUIDITY;
            lpShares[address(0)] = MINIMUM_LIQUIDITY;
            totalLpShares = shares + MINIMUM_LIQUIDITY;
            reserveYes = amountBase;
            reserveNo = amountBase;
        } else {
            uint256 yesShare = (amountBase * totalLpShares) / reserveYes;
            uint256 noShare = (amountBase * totalLpShares) / reserveNo;
            shares = PredictionMath.min(yesShare, noShare);
            reserveYes += amountBase;
            reserveNo += amountBase;
            lpShares[msg.sender] += shares;
            totalLpShares += shares;
        }

        emit LiquidityAdded(msg.sender, amountBase, amountBase, shares);
    }

    function removeLiquidity(uint256 shares)
        external nonReentrant returns (uint256 amountYes, uint256 amountNo)
    {
        if (shares == 0) revert ZeroAmount();
        if (lpShares[msg.sender] < shares) revert InsufficientShares();

        amountYes = (reserveYes * shares) / totalLpShares;
        amountNo = (reserveNo * shares) / totalLpShares;

        lpShares[msg.sender] -= shares;
        totalLpShares -= shares;
        reserveYes -= amountYes;
        reserveNo -= amountNo;

        outcomeToken.mint(msg.sender, outcomeIdYes, amountYes, "");
        outcomeToken.mint(msg.sender, outcomeIdNo, amountNo, "");

        emit LiquidityRemoved(msg.sender, shares, amountYes, amountNo);
    }

    function resolveMarket(uint8 _winner) external onlyRole(RESOLVER_ROLE) whenNotResolved {
        if (block.timestamp < resolutionTime) revert NotResolvedYet();
        if (_winner != 1 && _winner != 2) revert InvalidOutcome();
        winner = _winner;
        resolved = true;
        disputeEnd = block.timestamp + disputeWindow;
        emit MarketResolved(_winner, block.timestamp);
    }

    function raiseDispute() external onlyRole(MANAGER_ROLE) {
        if (!resolved) revert NotResolved();
        if (block.timestamp >= disputeEnd) revert DisputeWindowClosed();
        resolved = false;
        winner = 0;
        emit DisputeRaised(msg.sender);
    }

    function redeem(uint8 outcome) external whenResolved nonReentrant {
        if (outcome != winner) revert("Not winning outcome");
        uint256 tokenId = outcome == 1 ? outcomeIdYes : outcomeIdNo;
        uint256 balance = outcomeToken.balanceOf(msg.sender, tokenId);
        if (balance == 0) revert NoTokensToRedeem();

        uint256 totalPool = baseToken.balanceOf(address(this));
        uint256 winningReserve = outcome == 1 ? reserveYes : reserveNo;
        uint256 amount = (balance * totalPool) / winningReserve;
        if (amount == 0) revert NothingToRedeem();

        outcomeToken.burn(msg.sender, tokenId, balance);
        baseToken.safeTransfer(msg.sender, amount);
        emit Redeemed(msg.sender, outcome, amount);
    }

    function getPrice(uint8 outcome) external view returns (uint256) {
        if (reserveYes == 0 || reserveNo == 0) return 0;
        if (outcome == 1) return (reserveNo * 1e18) / (reserveYes + reserveNo);
        if (outcome == 2) return (reserveYes * 1e18) / (reserveYes + reserveNo);
        return 0;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveYes, reserveNo);
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal pure returns (uint256)
    {
        if (amountIn == 0 || reserveIn == 0 || reserveOut == 0) return 0;
        return (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    function _sendFees(uint256 amount) internal {
        if (amount > 0 && feeVault != address(0)) {
            baseToken.safeTransfer(feeVault, amount);
        }
    }
}
