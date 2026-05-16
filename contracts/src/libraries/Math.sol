pragma solidity ^0.8.23;

library PredictionMath {
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        assembly {
            if gt(y, 3) {
                z := y
                let r := div(y, 2)
                for {} gt(r, z) {} {
                    z := r
                    r := div(add(div(y, r), r), 2)
                }
            }
            if and(lt(y, 4), gt(y, 0)) { z := 1 }
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
