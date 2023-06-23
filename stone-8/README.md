# Stone-8

Testnet for Initia.

[initia@v0.1.0-beta.19](https://github.com/initia-labs/initia/releases/tag/v0.1.0-beta.19) should be used to run the testnet.

- The genesis event for Stone-8 testnet will occur **2023-04-26T05:30:01.519628518Z (UTC)**

## Prerequisites
* Go v1.19+ or higher
* Git
* curl
* jq

## How to Setup

Install binaries from [here](./binaries/) or you can install from the [source code](https://github.com/initia-labs/initia).

Download the genesis from [here](https://initia.s3.ap-southeast-1.amazonaws.com/stone-8/genesis.json).

```shell
$ git clone https://github.com/initia-labs/initia
$ git checkout v0.1.0-beta.19
$ make install

$ initiad version --long
name: initia
server_name: initiad
version: v0.1.0-beta.19
commit: b32d8952a2f4947e56f88a8225fb50b8ebfe7ca2
build_tags: netgo ledger,
go: go version go1.19.5 linux/amd64

$ initiad init [moniker] --chain-id stone-8
$ wget https://initia.s3.ap-southeast-1.amazonaws.com/stone-8/genesis.json
$ cp genesis.json ~/.initia/config/genesis.json

# This will prevent continuous reconnection try. (default P2P_PORT is 26656)
$ sed -i -e 's/external_address = \"\"/external_address = \"'$(curl httpbin.org/ip | jq -r .origin)':26656\"/g' ~/.initia/config/config.toml

$ initiad start
```

# How to setup validator

```
initiad tx mstaking create-validator \
    --amount=5000000uinit \   # It can be other LP tokens 
    --pubkey=$(initiad tendermint show-validator) \
    --moniker="<your_moniker>" \
    --chain-id=<chain_id> \
    --from=<key_name> \
    --commission-rate="0.10" \
    --commission-max-rate="0.20" \
    --commission-max-change-rate="0.01" \
    --identity=<keybase_identity> # (optional) for validator image
```

### Known Peers
```
c65d1a7f91d5a9d0c761359d806aed4758fc8006@13.213.52.28:26656
```
