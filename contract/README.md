# sando-rs/contract ![license](https://img.shields.io/badge/License-MIT-green.svg?label=license)

Gas optimized sando contract written in Huff to make use unconventional gas optimizations. 

> Why not Yul? Yul does not give access to the stack or jump instructions. 

## Gas Optimizations

### JUMPDEST Function Sig
Instead of reserving 4 bytes for a function selector, store a JUMPDEST in the first byte of calldata and jump to it at the beginning of execution. Doing so allows us to jump to the code range 0x00-0xFF, fill range with place holder JUMPDEST that point to location of function body. 

Example:
```as
#define macro MAIN() = takes (0) returns (0) {
    ...
    entry_point
    jumpi
    ...
    
    entry_point:
        chainid
        byte
        jump
```

### Encoding WETH Value Using tx.value
When dealing with WETH amounts, the amount is encoded by first dividing the value by 0x100000000, and setting the divided value as `tx.value` when calling the contract. The contract then multiplies `tx.value` by 0x100000000 to get the original amount. 

### Encoding Other Token Value Using 5 Bytes Of Calldata
When dealing with the other token amount, the values can range significantlly depending on token decimal and total supply. To account for full range, we encode by fitting the value into 4 bytes of calldata plus a byte shift. To decode, we byteshift the 4bytes to the left. 

We use byteshifts instead of bitshifts because we perform a byteshift by storing the 4bytes in memory N bytes to the left of its memory slot. 

However, instead of encoding the byteshift into our calldata, we encode the offset in memory such that when the 4bytes are stored, it will be N bytes from the left of its storage slot.

### Hardcoded values
Weth address is hardcoded into the contract and there are individual methods to handle when Weth is token0 or token1. 

### Encode Packed
All calldata is encoded by packing the values together.  

### Environment variables
Copy `.env.example` into `.env` and fill out values.  

```console
cp .env.example .env
```

```
HTTP_RPC_URL= // Mainnet JSON-RPC url. example: https://mainnet.infura.io/v3/<YOUR_INFURA_API_KEY>
PRIVATE_KEY= // Deployer private key(only for the deployment)
SEARCHER_PRIVATE_KEY= // Searcher(Attacker) private key to be used to interact with the deployed sandwich contract
SEARCHER=0x... // Searcher(Attacker) address
```


## Tests

```console
source .env
forge test --match-path test/Mev.t.sol --rpc-url $HTTP_RPC_URL -vvv
```

## Deployment
```console
source .env  
forge script ./script/Deploy.s.sol --rpc-url $HTTP_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

## Deposit WETH
```console
source .env  
forge script ./script/Deposit.s.sol --rpc-url $HTTP_RPC_URL --broadcast --sender $SEARCHER
```

## Withdraw WETH
```console
source .env  
forge script ./script/Withdraw.s.sol --rpc-url $HTTP_RPC_URL --broadcast --sender $SEARCHER
```

## Self destruct
```console
source .env  
forge script ./script/Seppuku.s.sol --rpc-url $HTTP_RPC_URL --broadcast --sender $SEARCHER
```

## Benchmarks
!todo
