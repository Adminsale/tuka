pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/libraries/YulBenchmark.sol";

contract YulBenchmarkTest is Test {
    using YulBenchmark for uint256;

    function test_SqrtYul() public {
        assertEq(YulBenchmark.sqrtYul(0), 0);
        assertEq(YulBenchmark.sqrtYul(1), 1);
        assertEq(YulBenchmark.sqrtYul(4), 2);
        assertEq(YulBenchmark.sqrtYul(16), 4);
        assertEq(YulBenchmark.sqrtYul(100), 10);
        assertEq(YulBenchmark.sqrtYul(144), 12);
        assertEq(YulBenchmark.sqrtYul(1e18), 1e9);
    }

    function test_SqrtSolidity() public {
        assertEq(YulBenchmark.sqrtSolidity(0), 0);
        assertEq(YulBenchmark.sqrtSolidity(1), 1);
        assertEq(YulBenchmark.sqrtSolidity(4), 2);
        assertEq(YulBenchmark.sqrtSolidity(16), 4);
        assertEq(YulBenchmark.sqrtSolidity(100), 10);
        assertEq(YulBenchmark.sqrtSolidity(144), 12);
        assertEq(YulBenchmark.sqrtSolidity(1e18), 1e9);
    }

    function test_SqrtYulVsSolidity() public {
        for (uint256 i = 0; i < 100; i++) {
            uint256 val = 10 ** i;
            if (val > type(uint256).max / 10) break;
            assertEq(YulBenchmark.sqrtYul(val), YulBenchmark.sqrtSolidity(val));
        }
    }

    function test_MulDivYul() public {
        assertEq(YulBenchmark.mulDivYul(100, 200, 50), 400);
        assertEq(YulBenchmark.mulDivYul(1e18, 1e18, 1e18), 1e18);
    }

    function test_MulDivSolidity() public {
        assertEq(YulBenchmark.mulDivSolidity(100, 200, 50), 400);
        assertEq(YulBenchmark.mulDivSolidity(1e18, 1e18, 1e18), 1e18);
    }

    function test_GasBenchmarkSqrt() public {
        uint256 gasYul = gasleft();
        for (uint256 i = 0; i < 100; i++) {
            YulBenchmark.sqrtYul(12345678901234567890);
        }
        uint256 gasUsedYul = gasYul - gasleft();

        uint256 gasSol = gasleft();
        for (uint256 i = 0; i < 100; i++) {
            YulBenchmark.sqrtSolidity(12345678901234567890);
        }
        uint256 gasUsedSol = gasSol - gasleft();

        emit log_named_uint("Gas per Yul sqrt (avg)", gasUsedYul / 100);
        emit log_named_uint("Gas per Solidity sqrt (avg)", gasUsedSol / 100);
    }
}
