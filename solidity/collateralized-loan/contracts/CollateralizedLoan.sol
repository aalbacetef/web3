// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AggregatorV3Interface.sol";

/**
 * @title A collateralized loan system implementation.
 * @author Arturo Albacete
 * @notice this is a proof-of-concept not meant for actual production.
 */
contract CollateralizedLoan is Ownable {
    uint256 public loanRequestFeePercentage;
    uint256 public settlementFeePercentage;
    uint256 public liquidationThreshold;
    uint256 public minInterestRate;
    uint256 public maxLTV;
    uint256 public maxLoanDurationInDays;

    TokenInfo[] public collateralTokens;
    TokenInfo[] public loanTokens;

    error InvalidInterestRate(uint256 interestRate);
    error InvalidCollateralToken();
    error InvalidLoanToken();
    error InvalidCollateralValue(uint256 amount);
    error InvalidLTV(uint256 LTV);
    error InvalidLoanDuration(uint256 durationInDays);
    error TokenNotFound(address tokenAddress);
    error NotEnoughCollateral(uint256 amount);

    event LoanRequestCreated(
        uint256 id,
        address borrower,
        uint256 collateralAmount,
        address collateralToken,
        uint256 loanAmount,
        address loanToken
    );

    LoanRequest[] public loanRequests;
    Loan[] public loans;
    uint256 private lastLoanRequestID;
    uint256 private lastLoanID;
    mapping(address => uint256[]) addressToLoanRequestIDs;
    mapping(address => uint256[]) addressToLoanIDs;
    mapping(uint256 => uint256) loanRequestIDToLoanID;

    /// @dev represents a token's address and its corresponding price feed address.
    struct TokenInfo {
        address addr;
        address priceFeed;
    }

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
    }

    struct Loan {
        uint256 id;
        uint256 loanRequestID;
        address lender;
        uint256 dateStarted;
        uint256 dateEnded;
        bool isPaid;
    }

    // @TODO: add min loan amount
    /**
     * @param _maxLTV Maximum ratio of loan to collateral value.
     * @param _loanRequestFeePercentage Percentage charged on the loan request, based on the loan amount.
     * @param _settlementFeePercentage Percentage charged for the settlement of the loan, based on the loan amount.
     * @param _liquidationThreshold Percentage of the loan value at which the loan is paid back to the lender.
     * @param _minInterestRate The minimum possible interest rate.
     * @param _maxLoanDurationInDays The maximum number of days a loan can be made.
     * @param _collateralTokens List of token addresses allowed as collateral.
     * @param _collateralTokenPriceFeeds List of collateral token price feeds.
     * @param _loanTokens List of token addresses and price feed addresses allowed to request as loans.
     * @param _loanTokenPriceFeeds List of loan token price feeds.
     */
    constructor(
        uint256 _maxLTV,
        uint256 _loanRequestFeePercentage,
        uint256 _settlementFeePercentage,
        uint256 _liquidationThreshold,
        uint256 _minInterestRate,
        uint256 _maxLoanDurationInDays,
        address[] memory _collateralTokens,
        address[] memory _collateralTokenPriceFeeds,
        address[] memory _loanTokens,
        address[] memory _loanTokenPriceFeeds
    ) Ownable(msg.sender) {
        require(
            _maxLTV > 0 && _maxLTV < 100,
            "max LTV must be within 0 and 100"
        );

        require(
            _loanRequestFeePercentage > 0,
            "loan request fee percentage must be > 0"
        );

        require(
            _settlementFeePercentage > 0,
            "settlement fee percentage must be > 0"
        );

        require(_liquidationThreshold > 0, "liquidation threshold must be > 0");

        require(_minInterestRate > 0, "minimum interest rate must be > 0");

        require(
            _collateralTokens.length > 0,
            "collateral tokens must not be empty"
        );

        require(_loanTokens.length > 0, "loan tokens must not be empty");

        require(
            _collateralTokens.length == _collateralTokenPriceFeeds.length,
            "collateral token and price feeds lengths don't match"
        );

        require(
            _loanTokens.length == _loanTokenPriceFeeds.length,
            "loan token and price feeds lengths don't match"
        );

        require(
            _maxLTV < _liquidationThreshold,
            "max LTV must be below liquidation threshold"
        );

        require(
            _maxLoanDurationInDays > 0,
            "max loan duration in days must be larger than 0"
        );

        maxLTV = _maxLTV;
        settlementFeePercentage = _settlementFeePercentage;
        loanRequestFeePercentage = _loanRequestFeePercentage;
        minInterestRate = _minInterestRate;
        liquidationThreshold = _liquidationThreshold;
        maxLoanDurationInDays = _maxLoanDurationInDays;

        lastLoanID = 0;
        lastLoanRequestID = 0;

        for (uint k = 0; k < _collateralTokens.length; k++) {
            collateralTokens.push(
                TokenInfo({
                    addr: _collateralTokens[k],
                    priceFeed: _collateralTokenPriceFeeds[k]
                })
            );
        }

        for (uint k = 0; k < _loanTokens.length; k++) {
            loanTokens.push(
                TokenInfo({
                    addr: _loanTokens[k],
                    priceFeed: _loanTokenPriceFeeds[k]
                })
            );
        }
    }

    // @NOTE: amounts may need to be padded (e.g: by 10 ** 18)
    function makeLoanRequest(
        uint256 collateralAmount,
        address collateralToken,
        uint256 loanAmount,
        address loanToken,
        uint256 interestRate,
        uint256 durationInDays
    ) external {
        address borrower = msg.sender;

        if (interestRate < minInterestRate) {
            revert InvalidInterestRate(interestRate);
        }

        // @NOTE: add check for max duration in days
        if (durationInDays <= 0) {
            revert InvalidLoanDuration(durationInDays);
        }

        validateLoanCollateral(
            collateralAmount,
            collateralToken,
            loanAmount,
            loanToken
        );

        validateBorrowerHasCollateral(
            borrower,
            collateralAmount,
            collateralToken
        );

        // @TODO: transfer loan request funds to account
        // @TODO: charge fees

        loanRequests.push(
            LoanRequest({
                id: lastLoanRequestID + 1,
                borrower: borrower,
                collateralAmount: collateralAmount,
                collateralToken: collateralToken,
                loanAmount: loanAmount,
                loanToken: loanToken,
                interestRate: interestRate,
                durationInDays: durationInDays,
                timeCreated: block.timestamp,
                expiredOrArchived: false
            })
        );

        lastLoanRequestID++;

        emit LoanRequestCreated(
            lastLoanRequestID,
            borrower,
            collateralAmount,
            collateralToken,
            loanAmount,
            loanToken
        );
    }

    // @dev Validates that the loan and collateral amounts are within the platform's range for LTV and that the tokens are accepted tokens.
    function validateLoanCollateral(
        uint256 collateralAmount,
        address collateralToken,
        uint256 loanAmount,
        address loanToken
    ) internal view {
        address loanTokenPriceFeed = getTokenPriceFeed(
            loanToken,
            loanTokens,
            loanTokens.length
        );
        address collateralTokenPriceFeed = getTokenPriceFeed(
            collateralToken,
            collateralTokens,
            collateralTokens.length
        );

        uint256 collateralValue = collateralAmount *
            getPrice(collateralTokenPriceFeed);
        uint256 loanValue = loanAmount * getPrice(loanTokenPriceFeed);

        if (collateralValue == 0) {
            revert InvalidCollateralValue(collateralValue);
        }

        // @NOTE: if the collateral is much, much, much larger than the loan, it might equal 0.
        // not sure if this would be problematic.
        uint256 LTV = (100 * loanValue) / collateralValue;

        if (LTV >= maxLTV) {
            revert InvalidLTV(LTV);
        }
    }

    // @NOTE: this function doesn't account for fees or gas fees.
    function validateBorrowerHasCollateral(
        address borrower,
        uint256 collateralAmount,
        address collateralToken
    ) internal view {
        IERC20 tokenContract = IERC20(collateralToken);

        if (tokenContract.balanceOf(borrower) < collateralAmount) {
            revert NotEnoughCollateral(collateralAmount);
        }
    }

    function getPrice(address priceFeed) internal view returns (uint256) {
        int256 price;

        (, price, , , ) = AggregatorV3Interface(priceFeed).latestRoundData();

        // @NOTE: for now we'll assume this is safe but in a production environment this will need to be handled differently (or operate entirely with int256).
        return uint256(price);
    }

    function getTokenPriceFeed(
        address token,
        TokenInfo[] storage tokenList,
        uint n
    ) internal view returns (address) {
        for (uint k = 0; k < n; k++) {
            if (tokenList[k].addr == token) {
                return tokenList[k].priceFeed;
            }
        }

        revert TokenNotFound(token);
    }

    function isValidCollateral(address token) internal view returns (bool) {
        return isTokenInList(token, collateralTokens, collateralTokens.length);
    }

    function isValidLoanToken(address token) internal view returns (bool) {
        return isTokenInList(token, loanTokens, loanTokens.length);
    }

    function isTokenInList(
        address token,
        TokenInfo[] memory tokenList,
        uint n
    ) internal pure returns (bool) {
        for (uint k = 0; k < n; k++) {
            if (tokenList[k].addr == token) {
                return true;
            }
        }

        return false;
    }

    function getLoanRequests() external view returns (LoanRequest[] memory) {
        LoanRequest[] memory retVal = new LoanRequest[](loanRequests.length);
        for (uint k = 0; k < loanRequests.length; k++) {
            retVal[k] = loanRequests[k]; // @TODO: copy struct
        }

        return retVal;
    }
}
