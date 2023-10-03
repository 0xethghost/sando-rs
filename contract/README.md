# Rusty-Sando/Contract ![license](https://img.shields.io/badge/License-MIT-green.svg?label=license)

Gas optimized sando contract written in Huff to make use unconventional gas optimizations. 

> Why not Yul? Yul does not give access to the stack or jump instructions. 

## Gas Optimizations

### JUMPDEST Function Sig
Instead of reserving 4 bytes for a function selector, store a JUMPDEST in the first byte of calldata and jump to it at the beginning of execution. Doing so allows us to jump to the code range 0x00-0xFF, fill range with place holder JUMPDEST that point to location of function body. 

Example:
```as
#define macro MAIN() = takes (0) returns (0) {
    // extract function selector (JUMPDEST encoding)
    returndatasize                              // [0x00]
    calldataload                                // [calldata]
    returndatasize                              // [0x00, calldata]
    byte                                        // [jumplabel]
    jump                                        // []
```

> **Note**
> JUMPDEST 0xfa is reserved to handle [UniswapV3 callback](https://docs.uniswap.org/contracts/v3/reference/core/interfaces/callback/IUniswapV3SwapCallback).

### Encoding WETH Value Using tx.value
When dealing with WETH amounts, the amount is encoded by first dividing the value by 0x100000000, and setting the divided value as `tx.value` when calling the contract. The contract then multiplies `tx.value` by 0x100000000 to get the original amount. 

### Encoding Other Token Value Using 5 Bytes Of Calldata
When dealing with the other token amount, the values can range significantlly depending on token decimal and total supply. To account for full range, we encode by fitting the value into 4 bytes of calldata plus a byte shift. To decode, we byteshift the 4bytes to the left. 

We use byteshifts instead of bitshifts because we perform a byteshift by storing the 4bytes in memory N bytes to the left of its memory slot. 

However, instead of encoding the byteshift into our calldata, we encode the offset in memory such that when the 4bytes are stored, it will be N bytes from the left of its storage slot.

> **Note** 
> Free alfa: Might be able to optimize contract by eliminating unnecessary [memory expansions](https://www.evm.codes/about#memoryexpansion) by changing order that params are stored in memory. I did not account for this when writing the contract. 

### Hardcoded values
Weth address is hardcoded into the contract and there are individual methods to handle when Weth is token0 or token1. 

### Encode Packed
All calldata is encoded by packing the values together. 

## Interface

| JUMPDEST  | Function Name |
| :-------------: | :------------- |
| 0x05  | V2 Swap, Weth is Token0 and Output  |
| 0x0A  | V2 Swap, Weth is Token0 and Input  |
| 0x0F  | V2 Swap, Weth is Token1 and Output  |
| 0x14  | V2 Swap, Weth is Token1 and Input |
| 0x19  | V3 Swap, Weth is Token1 and Output, Big Encoding |
| 0x1E  | V3 Swap, Weth is Token0 and Output, Big Encoding  |
| 0x23  | V3 Swap, Weth is Token1 and Output, Small Encoding  |
| 0x28  | V3 Swap, Weth is Token0 and Output, Small Encoding |
| 0x2D  | V3 Swap, Weth is Token0 and Input  |
| 0x32  | V3 Swap, Weth is Token1 and Input  |
| 0x37  | Seppuku (self-destruct)  |
| 0x3C  | Recover Eth  |
| 0x41  | Recover Weth  |
| 0x46  | Deposit Weth  |
| 0xFA  | UniswapV3 Callback  |


## Calldata Encoding 
### Uniswap V2 Calldata Encoding Format

#### When Weth is input (0x0A, 0x16)
| Byte Length  | Variable |
| :-------------: | :------------- |
| 1 | JUMPDEST  |
| 1 | Where to store AmountOut  |
| 20 | PairAddress  |
| 4 | AmountOut  |

#### When Weth is output (0x05, 0x2a)
| Byte Length  | Variable |
| :-------------: | :------------- |
| 1 | JUMPDEST  |
| 1 | Where to store AmountIn  |
| 20 | PairAddress  |
| 20 | TokenInAddress  |
| 4 | AmountIn  |

### Uniswap V3 Calldata Encoding Format

#### When Weth is input (0x2D, 0x33)
| Byte Length  | Variable |
| :-------------: | :------------- |
| 1 | JUMPDEST  |
| 20 | PairAddress  |
| 32 | PairInitHash  | 
> PairInitHash used to verify msg.sender is pool in callback

#### When Weth is output small (0x2D, 0x33)
| Byte Length  | Variable |
| :-------------: | :------------- |
| 1 | JUMPDEST  |
| 20 | PairAddress  |
| 20 | TokenInAddress  |
| 6 | AmountIn  | 
| 32 | PairInitHash  | 
> Small encoding when AmountIn < 10^12

#### When Weth is output big (0x19, 0x1F)
| Byte Length  | Variable |
| :-------------: | :------------- |
| 1 | JUMPDEST  |
| 20 | PairAddress  |
| 20 | TokenInAddress  |
| 9 | AmountIn  | 
| 32 | PairInitHash  | 
> AmountIn will be multiplied by 10^12

## Tests

```console
forge test --rpc-url <your-rpc-url-here>
```

## Deployment
```console
source .env  
forge script ./script/Deploy.s.sol --rpc-url $HTTPS_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

## Withdraw WETH
```console
source .env  
forge script ./script/Withdraw.s.sol --rpc-url $HTTPS_RPC_URL --broadcast --sender $SEARCHER
```

## Self destruct
```console
source .env  
forge script ./script/Seppuku.s.sol --rpc-url $HTTPS_RPC_URL --broadcast --sender $SEARCHER
```

## Benchmarks
!todo
