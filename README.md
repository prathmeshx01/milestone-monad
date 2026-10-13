# Milestone

**Transparent, milestone-based crowdfunding for student projects — a Monad Metropolis hackathon prototype.**

## Current status

This repository currently contains a static frontend prototype. Campaign examples are illustrative and campaign creation is local to the current browser session. Wallet transactions, Monad contract deployment, milestone approvals, and on-chain fund releases are **not yet implemented**.

## Product idea

Milestone explores how student teams and community builders can raise small amounts for practical projects while making campaign goals, progress, and funding rules easier to inspect.

## Prototype features

- Responsive campaign board with category filters
- Interactive campaign creation preview
- Example funding goals and milestone progress
- Custom SVG project mark
- Clear disclosure that demo actions do not move funds

## Planned next steps

1. Implement and test a Solidity funding contract with explicit access controls, milestone release rules, and refund/cancellation conditions.
2. Deploy to the Monad network allowed by the hackathon and verify transactions.
3. Connect a wallet and replace illustrative campaign data with contract reads and writes.
4. Test unauthorized release, duplicate release, and refund edge cases.

## Run locally

Open `index.html` in a browser. No build step is required.

## Built for

Monad Metropolis hackathon. This is a prototype and does not handle real funds.
