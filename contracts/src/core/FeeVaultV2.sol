pragma solidity ^0.8.23;

import "./FeeVault.sol";

contract FeeVaultV2 is FeeVault {
    uint256 public withdrawalFeeBps;
    uint256 public constant MAX_WITHDRAWAL_FEE = 500;

    event WithdrawalFeeUpdated(uint256 oldFee, uint256 newFee);

    error FeeTooHigh();

    function initializeV2(uint256 _withdrawalFeeBps) external reinitializer(2) {
        if (_withdrawalFeeBps > MAX_WITHDRAWAL_FEE) revert FeeTooHigh();
        withdrawalFeeBps = _withdrawalFeeBps;
    }

    function setWithdrawalFee(uint256 _feeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feeBps > MAX_WITHDRAWAL_FEE) revert FeeTooHigh();
        emit WithdrawalFeeUpdated(withdrawalFeeBps, _feeBps);
        withdrawalFeeBps = _feeBps;
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public override returns (uint256)
    {
        if (withdrawalFeeBps > 0) {
            uint256 fee = (assets * withdrawalFeeBps) / 10000;
            IERC20(asset()).transfer(receiver, fee);
        }
        return super.withdraw(assets, receiver, owner);
    }

    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}
