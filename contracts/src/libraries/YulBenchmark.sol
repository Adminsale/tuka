pragma solidity ^0.8.23;

library YulBenchmark {
    function sqrtYul(uint256 y) internal pure returns (uint256 z) {
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

    function sqrtSolidity(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 r = y / 2;
            while (r < z) {
                z = r;
                r = (y / r + r) / 2;
            }
        }
        if (y > 0 && y < 4) {
            z = 1;
        }
    }

    function mulDivYul(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        assembly {
            let prod := mul(x, y)
            result := div(prod, denominator)
        }
    }

    function mulDivSolidity(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256) {
        return (x * y) / denominator;
    }
}
