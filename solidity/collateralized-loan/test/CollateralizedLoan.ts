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
  minimumLoanAmount,
  loanRequestFeePercentage,
  settlementFeePercentage,
} from '@/lib';

describe('CollateralizedLoan', function() {
  async function deployDefault() {
    const contract = await hre.viem.deployContract('CollateralizedLoan', [
      BigInt(loanRequestFeePercentage),
      BigInt(settlementFeePercentage),
    ]);

    const publicClient = await hre.viem.getPublicClient();

    return { contract, publicClient };
  }

  describe('loan request', () => {
    it('should allow making a loan request', async () => {
      const { contract } = await loadFixture(deployDefault);

    });
  })
});
