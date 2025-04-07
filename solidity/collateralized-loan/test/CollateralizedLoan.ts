import {
  time,
  loadFixture,
} from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import { expect } from 'chai';
import hre from 'hardhat';
import { getAddress, parseGwei } from 'viem';

import {
  maxLTV,
  liquidationThreshold,
  minInterestRate,
  minimumLoanAmount,
  maxLoanDurationInDays,
  loanRequestFeePercentage,
  settlementFeePercentage,
} from '../lib/defaults';
import { shouldFailWithError, shouldFulfill } from './helper';

function getTokenInfoList() {
  const toPrice = (price: number) => BigInt(Math.floor(1e8 * price));

  type Token = {
    sym: string;
    price: bigint;
  };

  const tokens: Token[] = [
    { sym: 'ETH', price: toPrice(1680) },
    { sym: 'BTC', price: toPrice(79020.48) },
    { sym: 'USDC', price: toPrice(1.000034) },
    { sym: 'USDT', price: toPrice(1) },
    { sym: 'EURT', price: toPrice(1.096467) },
  ];

  const collateralTokens = tokens.slice(0, 2);
  const loanTokens = tokens.slice(2);

  return { tokens, collateralTokens, loanTokens };
}

async function deployPriceFeedsAndTokens() {
  const initialSupply = BigInt(1_000_000) * BigInt(10 ** 18);
  const { tokens, collateralTokens } = getTokenInfoList();

  const tokenContracts = new Array(tokens.length);
  const priceFeeds = new Array(tokens.length);

  for (let k = 0; k < tokens.length; k++) {
    const token = tokens[k];

    tokenContracts[k] = await hre.viem.deployContract('MockToken', [
      token.sym,
      token.sym,
      initialSupply,
    ]);

    priceFeeds[k] = await hre.viem.deployContract('MockPriceFeed', [
      tokenContracts[k].address,
      token.price,
    ]);
  }

  const collateralTokenPriceFeeds = priceFeeds.slice(
    0,
    collateralTokens.length
  );
  const loanTokenPriceFeeds = priceFeeds.slice(collateralTokens.length);
  const collateralTokenContracts = tokenContracts.slice(
    0,
    collateralTokens.length
  );
  const loanTokenContracts = tokenContracts.slice(collateralTokens.length);

  return {
    priceFeeds,
    tokenContracts,
    collateralTokenPriceFeeds,
    loanTokenPriceFeeds,
    collateralTokenContracts,
    loanTokenContracts,
  };
}

describe('CollateralizedLoan', function () {
  async function deployDefault() {
    const { collateralTokens, loanTokens } = getTokenInfoList();
    const {
      collateralTokenPriceFeeds,
      loanTokenPriceFeeds,
      collateralTokenContracts,
      loanTokenContracts,
    } = await deployPriceFeedsAndTokens();

    const contract = await hre.viem.deployContract('CollateralizedLoan', [
      BigInt(maxLTV),
      BigInt(loanRequestFeePercentage),
      BigInt(settlementFeePercentage),
      BigInt(liquidationThreshold),
      BigInt(minInterestRate),
      BigInt(maxLoanDurationInDays),
      collateralTokenContracts.map((tokenContract) => tokenContract.address),
      collateralTokenPriceFeeds.map((priceFeed) => priceFeed.address),
      loanTokenContracts.map((tokenContract) => tokenContract.address),
      loanTokenPriceFeeds.map((priceFeed) => priceFeed.address),
    ]);

    const publicClient = await hre.viem.getPublicClient();

    return {
      contract,
      publicClient,
      collateralTokenPriceFeeds,
      loanTokenPriceFeeds,
      collateralTokens,
      loanTokens,
      collateralTokenContracts,
      loanTokenContracts,
    };
  }

  describe('loan request', () => {
    it('should fail making a loan request if not enough collateral is present', async () => {
      const {
        contract,
        collateralTokens,
        loanTokens,
        collateralTokenContracts,
        loanTokenContracts,
      } = await loadFixture(deployDefault);

      const wallets = await hre.viem.getWalletClients();
      const borrower = wallets[3];
      const ethToken = collateralTokenContracts.find(
        (_, index) => collateralTokens[index].sym === 'ETH'
      );
      const usdcToken = loanTokenContracts.find(
        (_, index) => loanTokens[index].sym === 'USDC'
      );

      const loanRequestInfo = {
        collateralAmount: 2,
        collateralToken: ethToken.address,
        loanAmount: 200,
        loanToken: usdcToken.address,
        interestRate: 85, // 8.5%,
        durationInDays: 150,
      };

      await shouldFailWithError(
        contract.write.makeLoanRequest(
          [
            BigInt(loanRequestInfo.collateralAmount),
            loanRequestInfo.collateralToken,
            BigInt(loanRequestInfo.loanAmount),
            loanRequestInfo.loanToken,
            BigInt(loanRequestInfo.interestRate),
            BigInt(loanRequestInfo.durationInDays),
          ],
          { account: borrower.account }
        ),
        'NotEnoughCollateral'
      );
    });

    it('should fail making a loan request if not enough collateral is present', async () => {
      const {
        contract,
        publicClient,
        collateralTokens,
        loanTokens,
        collateralTokenContracts,
        loanTokenContracts,
      } = await loadFixture(deployDefault);

      const initialLoanRequests = await contract.read.getLoanRequests();
      expect(initialLoanRequests.length).to.be.equal(
        0,
        'should initially be empty'
      );

      const wallets = await hre.viem.getWalletClients();
      const borrower = wallets[3];
      const ethToken = collateralTokenContracts.find(
        (_, index) => collateralTokens[index].sym === 'ETH'
      );
      const usdcToken = loanTokenContracts.find(
        (_, index) => loanTokens[index].sym === 'USDC'
      );

      const loanRequestInfo = {
        collateralAmount: 2,
        collateralToken: ethToken.address,
        loanAmount: 200,
        loanToken: usdcToken.address,
        interestRate: 85, // 8.5%,
        durationInDays: 150,
      };

      // give borrower twice as much as needed
      await shouldFulfill(
        publicClient,
        ethToken.write.mint([
          borrower.account.address,
          BigInt(loanRequestInfo.collateralAmount * 2),
        ])
      );

      await shouldFulfill(
        publicClient,
        contract.write.makeLoanRequest(
          [
            BigInt(loanRequestInfo.collateralAmount),
            loanRequestInfo.collateralToken,
            BigInt(loanRequestInfo.loanAmount),
            loanRequestInfo.loanToken,
            BigInt(loanRequestInfo.interestRate),
            BigInt(loanRequestInfo.durationInDays),
          ],
          { account: borrower.account }
        )
      );

      const loanRequests = await contract.read.getLoanRequests();
      expect(loanRequests.length).to.be.equal(
        1,
        'it should have one loan request'
      );
    });
  });
});
