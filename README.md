## Interchain Secuirty Devnet Test
**Based on [ICS-testnet](https://github.com/sainoe/ICS-testnet)**

### Setup
**Requirements**
[Go 1.18+](https://go.dev/dl/)
[jq](https://stedolan.github.io/jq/download/)

### Getting Started
For this devnet, Gaia will be the provider chain.

Bootstrap the node
```
chmod +x init.sh
./init.sh
```

Query staking providers
`./interchain-security-pd q staking validators --home ./provider`
