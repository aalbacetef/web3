// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

contract MockPriceFeed {
    address public tokenAddress;
    int256 public mockPrice;

    constructor(address _tokenAddress, int256 _mockPrice) {
        tokenAddress = _tokenAddress;
        mockPrice = _mockPrice;
    }

    /// @dev it is a mock function so we only return the mock price.
    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, mockPrice, 0, 0, 0);
    }
}
