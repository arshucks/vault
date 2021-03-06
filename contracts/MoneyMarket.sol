pragma solidity ^0.4.19;

import "./Ledger.sol";
import "./Supplier.sol";
import "./Borrower.sol";

/**
  * @title The Compound MoneyMarket Contract
  * @author Compound
  * @notice The Compound MoneyMarket Contract in the core contract governing
  *         all accounts in Compound.
  */
contract MoneyMarket is Ledger, Supplier, Borrower {

    /**
      * @notice `MoneyMarket` is the core Compound MoneyMarket contract
      */
    function MoneyMarket() public {
    }

    /**
      * @notice Combines both `customerBorrow` and `customerWithdraw` into one function call
      * @param asset The asset to borrow
      * @param amount The amount to borrow
      * @param to The address to withdraw to
      * @return success or failure
      */
    function customerBorrowAndWithdraw(address asset, uint256 amount, address to) public returns (bool) {
      if (!customerBorrow(asset, amount)) {
        return false;
      }

      if (!customerWithdraw(asset, amount, to)) {
        return false;
      }

      return true;
    }

    /**
      * @notice Do not pay directly into MoneyMarket, please use `supply`.
      */
    function() payable public {
        revert();
    }
}
