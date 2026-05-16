pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./PredictionMarket.sol";
import "../tokens/OutcomeToken.sol";

contract MarketFactory is AccessControl {
    using Clones for address;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public outcomeTokenImplementation;
    address public marketImplementation;
    address public baseToken;
    address public feeVault;
    address public priceFeed;
    uint16 public defaultFeeBps;
    uint256 public disputeWindow;

    uint256 public marketCount;
    mapping(uint256 => address) public markets;
    mapping(address => bool) public isMarket;

    event MarketDeployed(uint256 indexed id, address indexed market, string question);
    event MarketDeployedCreate2(uint256 indexed id, address indexed market, bytes32 salt);

    constructor(
        address _outcomeTokenImpl,
        address _marketImpl,
        address _baseToken,
        address _feeVault,
        address _priceFeed,
        uint16 _defaultFeeBps,
        uint256 _disputeWindow
    ) {
        outcomeTokenImplementation = _outcomeTokenImpl;
        marketImplementation = _marketImpl;
        baseToken = _baseToken;
        feeVault = _feeVault;
        priceFeed = _priceFeed;
        defaultFeeBps = _defaultFeeBps;
        disputeWindow = _disputeWindow;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function deployMarket(string calldata question, uint256 resolutionTime)
        external returns (address)
    {
        return _deploy(question, resolutionTime, false, bytes32(0));
    }

    function deployMarketDeterministic(
        string calldata question,
        uint256 resolutionTime,
        bytes32 salt
    ) external returns (address) {
        return _deploy(question, resolutionTime, true, salt);
    }

    function _deploy(
        string calldata question,
        uint256 resolutionTime,
        bool useCreate2,
        bytes32 salt
    ) internal returns (address) {
        uint256 nextId = ++marketCount;

        OutcomeToken ot = new OutcomeToken(
            string.concat("Outcome-", vmToString(nextId)),
            string.concat("OC-", vmToString(nextId)),
            string.concat("https://api.predmarket.io/metadata/", vmToString(nextId), "/")
        );

        uint256 yesId = uint256(keccak256(abi.encodePacked(nextId, uint8(1))));
        uint256 noId = uint256(keccak256(abi.encodePacked(nextId, uint8(2))));

        address market;
        if (useCreate2) {
            bytes32 finalSalt = keccak256(abi.encodePacked(salt, nextId));
            market = _deployCreate2(question, resolutionTime, address(ot), yesId, noId, finalSalt);
        } else {
            market = _deployCreate(question, resolutionTime, address(ot), yesId, noId);
        }

        ot.grantRole(ot.MINTER_ROLE(), market);
        ot.grantRole(ot.BURNER_ROLE(), market);
        ot.revokeRole(ot.DEFAULT_ADMIN_ROLE(), address(this));

        markets[nextId] = market;
        isMarket[market] = true;

        if (useCreate2) {
            emit MarketDeployedCreate2(nextId, market, salt);
        } else {
            emit MarketDeployed(nextId, market, question);
        }

        return market;
    }

    function _deployCreate(
        string memory question,
        uint256 resolutionTime,
        address ot,
        uint256 yesId,
        uint256 noId
    ) internal returns (address) {
        PredictionMarket pm = new PredictionMarket(
            question, resolutionTime, disputeWindow,
            ot, yesId, noId,
            baseToken, defaultFeeBps, feeVault, priceFeed, msg.sender
        );
        pm.grantRole(pm.DEFAULT_ADMIN_ROLE(), address(this));
        return address(pm);
    }

    function _deployCreate2(
        string memory question,
        uint256 resolutionTime,
        address ot,
        uint256 yesId,
        uint256 noId,
        bytes32 salt
    ) internal returns (address) {
        bytes memory initCode = abi.encodePacked(
            type(PredictionMarket).creationCode,
            abi.encode(
                question, resolutionTime, disputeWindow,
                ot, yesId, noId,
                baseToken, defaultFeeBps, feeVault, priceFeed, msg.sender
            )
        );
        address market;
        assembly {
            market := create2(0, add(initCode, 0x20), mload(initCode), salt)
            if iszero(market) { revert(0, 0) }
        }
        PredictionMarket(payable(market)).grantRole(
            PredictionMarket(payable(market)).DEFAULT_ADMIN_ROLE(),
            address(this)
        );
        return market;
    }

    function vmToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function getMarketCount() external view returns (uint256) {
        return marketCount;
    }

    function getMarkets(uint256 offset, uint256 limit) external view returns (address[] memory) {
        uint256 end = offset + limit;
        if (end > marketCount) end = marketCount;
        uint256 len = end - offset;
        address[] memory result = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = markets[offset + i + 1];
        }
        return result;
    }

    function getDeployAddress(bytes32 salt) external view returns (address) {
        return address(uint160(uint256(
            keccak256(abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(type(PredictionMarket).creationCode)
            ))
        )));
    }
}
