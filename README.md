# Rusty-Sando !  
A practical MEV bot on how to perform V2/V3 and multi-meat sandwich attacks written using Rust and Huff.

## Brief Explanation
Anytime that a transaction interacts with a Uniswap V2/V3 pool and their forks, there is some slippage introduced (router swaps, aggregator swaps, other mev bots). Sandwich bots are a toxic form of MEV as they profit off this slippage by frontrunning the transaction pushing the price of the asset up to the slippage limit and then immediately selling the asset through a backrun transaction.

## Features
- **Fully Generalized**: Sandwich any tx that introduces slippage (routers, aggregators, mev bots, ...).
- **V2 and V3 Logic**: Logic to handle Uniswap V2/V3 pools.
- **Multi-Meat**: Build and send multi-meat sandwiches.
- **Gas Optimized**: Contract written in Huff using unconventional gas optimizations.
- **Local Simulations**: Fast concurrent EVM simulations to find sandwich opportunities. 
- **Token Dust**: Stores dust at the end of every bundle for lower gas usage next time token is traded. 
- **Salmonella Checks**: Detect if tx uses unusual opcodes that may produce different mainnet results.
- **Discord Logging**: Send notifications via discord webhooks.

**Bot Logic Breakdown** can be found under [bot/README.md](https://github.com/sipovalovdmitro/rusty-sando/tree/main/bot)

**Contract Logic Breakdown** can be found under [contract/README.md](https://github.com/sipovalovdmitro/rusty-sando/tree/main/contract)

## Acknowledgments
- [subway](https://github.com/libevm/subway)
- [subway-rs](https://github.com/refcell/subway-rs)
- [cfmms-rs](https://github.com/0xKitsune/cfmms-rs)
- [revm](https://github.com/bluealloy/revm)
- [huff-language](https://github.com/huff-language/huff-rs)
- [foundry](https://github.com/foundry-rs/foundry)
- [reth](https://github.com/paradigmxyz/reth)
- [ethers-rs](https://github.com/gakonst/ethers-rs)
- [mev-template-rs](https://github.com/degatchi/mev-template-rs)
- [rusty-sando](https://github.com/mouseless-eth/rusty-sando)
