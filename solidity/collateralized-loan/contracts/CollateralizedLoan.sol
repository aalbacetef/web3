// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
 * @title A collateralized loan system implementation.
 * @author Arturo Albacete 
 * @notice this is a proof-of-concept not meant for actual production.
 */
contract CollateralizedLoan {

  /// @dev the owner of the contract and the only one allowed to perform certain operations.
  address payable owner; 

  uint256 public loanRequestFeePercentage;
  uint256 public settlementFeePercentage;
  uint256 public liquidationThreshold;
  uint256 public minInterestRate;
  uint256 public maxLTV;

  address[] public collateralTokens;
  address[] public loanTokens;

  error InvalidInterestRate(uint256 interestRate);
  error InvalidCollateralToken();
  error InvalidLoanToken();
  error InvalidCollateralValue(uint256 amount);
  error InvalidLTV(uint256 LTV);

  LoanRequest[] public loanRequests;
  Loan[] public loans;
  mapping(address => uint256[]) addressToLoanRequestIDs;
  mapping(address => uint256[]) addressToLoanIDs;
  mapping(uint256 => uint256) loanRequestIDToLoanID;


  // @dev an external system will automatically expire stale LoanRequests.
  struct LoanRequest {
    uint256 id;
    address borrower;
    uint256 collateralAmount;
    address collateralToken;
    uint256 loanAmount;
    address loanToken;
    uint256 interestRate;
    uint256 durationInDays;
    uint256 timeCreated;
    bool expiredOrArchived;
  };

  struct Loan {
    uint256 id;
    uint256 loanRequestID;
    address lender;
    uint256 dateStarted;
    uint256 dateEnded;
    bool isPaid;
  };

  /**
   * @param _maxLTV Maximum ratio of loan to collateral value. 
   * @param _loanRequestFeePercentage Percentage charged on the loan request, based on the loan amount. 
   * @param _settlementFeePercentage Percentage charged for the settlement of the loan, based on the loan amount. 
   * @param _liquidationThreshold Percentage of the loan value at which the loan is paid back to the lender.
   * @param _minInterestRate The minimum possible interest rate.
   * @param _collateralTokens List of token addresses allowed as collateral. 
   * @param _loanTokens List of token addresses allowed to request as loans.
   */
  constructor(
    uint256 _loanRequestFeePercentage, 
    uint256 _settlementFeePercentage,
    uint256 _liquidationThreshold,
    uint256 _minInterestRate,
    address[] memory _collateralTokens, 
    address[] memory _loanTokens
  ) {
    require(
      _maxLTV > 0 && _maxLTV < 100,
      "max LTV must be within 0 and 100"
    );

    require(
      _loanRequestFeePercentage > 0,
      "loan request fee percentage must be > 0",
    );

    require(
      _settlementFeePercentage > 0,
      "settlement fee percentage must be > 0",
    );

    require(
      _liquidationThreshold > 0,
      "liquidation threshold must be > 0",
    );

    require(
      _minInterestRate > 0,
      "minimum interest rate must be > 0",
    );

    require(
      _collateralTokens.length > 0,
      "collateral tokens must not be empty"
    );

    require(
      _loanTokens.length > 0,
      "loan tokens must not be empty"
    );

    require(
      _maxLTV < _liquidationThreshold,
      "max LTV must be below liquidation threshold",
    );

    owner = payable(msg.sender);
    maxLTV = _maxLTV;
    settlementFeePercentage = _settlementFeePercentage;
    loanRequestFeePercentage = _loanRequestFeePercentage;
    minInterestRate = _minInterestRate;
    liquidationThreshold = _liquidationThreshold;
    collateralTokens = _collateralTokens;
    loanTokens = _loanTokens;    
  }

  function makeLoanRequest(
    uint256 collateralAmount,
    address collateralToken,
    uint256 loanAmount,
    address loanToken,
    uint256 interestRate,
    uint256 durationInDays, 
  ) {
    address borrower = msg.sender;

    if (interestRate < minInterestRate) {
      revert InvalidInterestRate(interestRate);
    }

    validateLoanCollateral(
      collateralAmount, 
      collateralToken, 
      loanAmount, 
      loanToken,
    );



  }

  // @dev Validates that the loan and collateral amounts are within the platform's range for LTV and that the tokens are accepted tokens. 
  function validateLoanCollateral(
    uint256 collateralAmount,
    address collateralToken,
    uint256 loanAmount,
    address loanToken,
  ) internal view {
    if (!isValidCollateral(collateralToken)) {
      revert InvalidCollateralToken();
    }

    if(!isValidLoanToken(loanToken)) {
      revert InvalidLoanToken();
    }

    uint256 collateralValue = collateralAmount * getPrice(collateralToken);
    uint256 loanValue = loanAmount * getPrice(loanToken);

    if(collateralValue == 0) {
      revert InvalidCollateralValue(collateralValue);
    }

    // @NOTE: if the collateral is much, much, much larger than the loan, it might equal 0.
    // not sure if this would be problematic.
    uint256 LTV = (100 * loanValue) / collateralValue ; 

    if (LTV >= maxLTV) {
      revert InvalidLTV(LTV);
    }
  }

  // STUB
  function getPrice(uint256 amount, address token) internal view returns (uint256) {
    return 0;
  }

  function isValidCollateral(address token) internal view returns (bool) {
    return isTokenInList(token, collateralTokens, collateralTokens.length);
  }

  function isValidLoanToken(address token) internal view returns (bool) {
    return isTokenInList(token, loanTokens, loanTokens.length);
  }

  function isTokenInList(address token, address[] memory tokenList, uint n) internal pure returns (bool) {
    for(uint k = 0; k < n; k++) {
      if(tokenList[k] == token) {
        return true; 
      }
    }

    return false;
  }
}
