pragma solidity ^0.4.19;

import "./Ledger.sol";
import "./base/Owned.sol";
import "./base/Graceful.sol";
import "./storage/PriceOracle.sol";

contract CollateralCalculator is Graceful, Owned, Ledger {

    PriceOracle public priceOracle;

    // Minimum collateral to borrow ratio. Must be >= 1 when divided by collateralRatioScale.
    uint256 public minimumCollateralRatio = 2 * collateralRatioScale;

    uint256 public constant collateralRatioScale = 1; // TODO: Raise to 10000 after refactor.

    event MinimumCollateralRatioChange(uint256 newMinimumCollateralRatio);

    /**
      * @notice `setPriceOracle` sets the priceOracle storage location for this contract
      * @dev This is for long-term data storage (TODO: Test)
      * @param priceOracleAddress The contract which acts as the long-term PriceOracle store
      * @return Success of failure of operation
      */
    function setPriceOracle(address priceOracleAddress) public returns (bool) {
        if (!checkOwner()) {
            return false;
        }

        priceOracle = PriceOracle(priceOracleAddress);

        return true;
    }

    /**
      * @notice `setMinimumCollateralRatio` sets the minimum collateral ratio
      * @param minimumCollateralRatio_ the minimum collateral ratio to be set
      * @dev used like this to gate borrow creation: borrower_account_value * minimumCollateralRatio >= borrow_amount
      * @return success or failure
      */
    function setMinimumCollateralRatio(uint256 minimumCollateralRatio_) public returns (bool) {
        if (!checkOwner()) {
            return false;
        }

        minimumCollateralRatio = minimumCollateralRatio_;

        MinimumCollateralRatioChange(minimumCollateralRatio_);

        return true;
    }

    /**
      * TODO: This should be available in Supplier.sol to gate withdrawals
      * @notice `getMaxWithdrawAvailable` gets the maximum withdrawal value available given supply and any outstanding borrows
      * It is supply - (borrows * minimumCollateralRatio)
      * @param account the address of the account
      * @return uint256 the maximum eth-equivalent value that can be withdrawn
      */
    function getMaxWithdrawAvailable(address account) public returns (uint256) {

        ValueEquivalents memory ve = getValueEquivalents(account);

        uint256 ratioAdjustedBorrow = (ve.borrowValue * minimumCollateralRatio)/ collateralRatioScale;
        //failure("DEBUG::getMaxWithdrawAvailable: ratioAdjustedBorrow, ve.supplyValue", ratioAdjustedBorrow, ve.supplyValue);
        if(ratioAdjustedBorrow >= ve.supplyValue) {
            return 0;
        }
        return ve.supplyValue - ratioAdjustedBorrow;
    }

    /**
      * @notice `getMaxBorrowAvailable` gets the maximum borrow available given supply and any outstanding borrows
      * It is maxWithdrawAvailable / minimumCollateralRatio
      * @param account the address of the account
      * @return uint256 the maximum additional eth equivalent borrow value that can be added to account
      */
    function getMaxBorrowAvailable(address account) public returns (uint256) {

        return (getMaxWithdrawAvailable(account) * collateralRatioScale) / minimumCollateralRatio;
    }

    /**
      *
      * @notice `validCollateralRatioBorrower` determines if the requested borrow amount is valid for the specified borrower
      * based on the minimum collateral ratio
      * @param borrower the borrower whose collateral should be examined
      * @param borrowAmount the requested (or current) borrow amount
      * @param borrowAsset denomination of borrow
      * @return boolean true if the requested amount is valid and false otherwise
      */
    function validCollateralRatioBorrower(address borrower, uint256 borrowAmount, address borrowAsset) internal returns (bool) {

        uint256 borrowValue = priceOracle.getAssetValue(borrowAsset, borrowAmount);
        uint256 maxBorrowAvailable = getMaxBorrowAvailable(borrower);

        bool result = maxBorrowAvailable >= borrowValue;
        if(!result) {
            failure("Borrower::InvalidCollateralRatio", uint256(borrowAsset), borrowAmount, borrowValue, maxBorrowAvailable);
        }
        return result;
    }

    /**
      * @notice `collateralShortfall` returns eth equivalent value of collateral needed to bring borrower to a valid collateral ratio,
      * @param borrower account to check
      * @return the collateral shortfall value, or 0 if borrower has enough collateral
      */
    function collateralShortfall(address borrower) public returns (uint256) {

        ValueEquivalents memory ve = getValueEquivalents(borrower);

        uint256 ratioAdjustedBorrow = (ve.borrowValue * minimumCollateralRatio) / collateralRatioScale;

        uint256 result = 0;
        if(ratioAdjustedBorrow > ve.supplyValue) {
            result = ratioAdjustedBorrow - ve.supplyValue;
        }
        //failure("DEBUG::collateralShortfall: ratioAdjustedBorrow, ve.supplyValue, result", ratioAdjustedBorrow, ve.supplyValue, result);
        return result;
    }

    // There are places where it is useful to have both total supplyValue and total borrowValue.
    // This struct lets us get both at once in one loop over assets.
    struct ValueEquivalents {
        uint256 supplyValue;
        uint256 borrowValue;
    }

    function getValueEquivalents(address acct) internal returns (ValueEquivalents memory) {
        uint256 assetCount = priceOracle.getAssetsLength(); // from PriceOracle
        uint256 supplyValue = 0;
        uint256 borrowValue = 0;

        for (uint64 i = 0; i < assetCount; i++) {
            address asset = priceOracle.assets(i);
            supplyValue += priceOracle.getAssetValue(asset, getBalance(acct, LedgerAccount.Supply, asset));
            borrowValue += priceOracle.getAssetValue(asset, getBalance(acct, LedgerAccount.Borrow, asset));
        }
        return ValueEquivalents({supplyValue: supplyValue, borrowValue: borrowValue});
    }
}