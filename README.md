# Milestone

Milestone is a Monad hackathon prototype exploring transparent crowdfunding with on-chain milestone releases.

## Repository status

- `index.html` and `logo.svg`: frontend prototype.
- `contracts/Milestone.sol`: initial Solidity contract implementation.
- **Important:** the contract has not been deployed or independently audited. The current frontend is not yet connected to this contract. Do not use real funds.

## Contract design

- Campaign creators set a goal, deadline, and milestone payout shares totaling 100%.
- Contributors send native MON directly to the contract.
- A campaign can proceed only if the exact funding goal is reached.
- The creator submits an evidence URI for the current milestone.
- Contributors vote with weight equal to their contribution; approval requires yes votes representing at least 50% of the total raised value.
- Each approved milestone releases its predefined share to the creator; the final milestone receives any rounding remainder.
- If the goal is not reached by the deadline, contributors can claim their contributions back.

## Current network target

Monad Testnet (chain ID 10143). RPC and faucet details: https://docs.monad.xyz/developer-essentials/testnet

## Before a public demo

1. Compile and test the contract in Remix or Foundry.
2. Deploy to Monad Testnet and record the contract address and deployment transaction.
3. Connect the frontend to the deployed address and wallet.
4. Test failed-goal refunds, vote thresholds, payout sequencing, duplicate votes, and creator-only milestone submissions.
5. Treat the contract as experimental until reviewed; never use real funds.
