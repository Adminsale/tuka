pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";

interface AggregatorV3Interface {
    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
}

contract ChainlinkPriceFeed is Ownable {
    AggregatorV3Interface public aggregator;
    uint256 public stalenessThreshold;

    event AggregatorUpdated(address indexed oldAgg, address indexed newAgg);
    event StalenessThresholdUpdated(uint256 oldVal, uint256 newVal);

    constructor(address _aggregator, uint256 _stalenessThreshold) Ownable(msg.sender) {
        aggregator = AggregatorV3Interface(_aggregator);
        stalenessThreshold = _stalenessThreshold;
    }

    function setAggregator(address _newAgg) external onlyOwner {
        emit AggregatorUpdated(address(aggregator), _newAgg);
        aggregator = AggregatorV3Interface(_newAgg);
    }

    function setStalenessThreshold(uint256 _threshold) external onlyOwner {
        emit StalenessThresholdUpdated(stalenessThreshold, _threshold);
        stalenessThreshold = _threshold;
    }

    function getPrice() external view returns (uint256) {
        (uint80 roundId, int256 answer, , uint256 updatedAt, uint80 answeredInRound) = aggregator.latestRoundData();
        if (answer <= 0) revert("ChainlinkPriceFeed: price is not positive");
        if (block.timestamp - updatedAt > stalenessThreshold) revert("ChainlinkPriceFeed: price is stale");
        if (answeredInRound < roundId) revert("ChainlinkPriceFeed: round not complete");
        return uint256(answer);
    }

    function decimals() external view returns (uint8) {
        return aggregator.decimals();
    }
}
