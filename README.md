## Interchain Security Localnet
**Based on [ICS-testnet](https://github.com/sainoe/ICS-testnet)**

### Setup
**Requirements**
[Go 1.18+](https://go.dev/dl/)
[jq](https://stedolan.github.io/jq/download/)

### Getting Started
For this localnet, Gaia will be the provider chain. More consumer chains will be added.

The init script provides the option of building both provider (`gaiad`) chain and consumer (`interchain-security`) chain binaries, configuring/running a single validator node for each, and bootstrapping the hermes relayer.

The script also allows to optionally submit a gov proposal to add a consumer chain on the provider chain.

Run the init script
```shell
chmod +x init.sh
./init.sh
```

View logs
```shell
# Provider logs
tail -f provider/logs

# Consumer logs
tail -f consumer/logs

# Hermes logs
tail -f hermes/logs
```

Once both chains are up, the gov proposal passed, and the relayer running, run the following queries to confirm the setup is running as expected:

[ICS-Devnet - Test CCV Protocol](https://github.com/sainoe/ICS-testnet/blob/main/start-testnet-tutorial.md#test-the-ccv-protocol)
