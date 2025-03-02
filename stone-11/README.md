# Stone-11

Testnet for Initia.

- The genesis event for Stone-11 testnet started at **2023-10-05T03:58:46.908179073Z (UTC)**

## Binaries

| height  | link  |
| ------- | ----- |
| 0~      | [initia@v0.1.1-beta.7](https://github.com/initia-labs/initia/releases/tag/v0.1.1-beta.7) |

## Prerequisites

- Go v1.19+ or higher
- Git
- curl
- jq

## How to Setup

Install binaries from [here](./binaries/) or you can install from the [source code](https://github.com/initia-labs/initia).

Download the genesis from [here](https://initia.s3.ap-southeast-1.amazonaws.com/stone-11/genesis.json).

```shell
# you can install initiad from the s3
# $ wget https://initia.s3.ap-southeast-1.amazonaws.com/stone-11/initia_0.1.1-beta.5_Darwin_aarch64.tar.gz
# $ wget https://initia.s3.ap-southeast-1.amazonaws.com/stone-11/initia_0.1.1-beta.5_Linux_x86_64.tar.gz

# or, build from the source
$ git clone https://github.com/initia-labs/initia
$ git checkout v0.1.1-beta.7
$ make install

$ initiad version --long
build_tags: netgo,ledger
commit: a3ec8ed439374a551aef40fc1566657e14d08dc6
cosmos_sdk_version: v0.47.3
go: go version go1.20.6 darwin/arm64
name: initia
server_name: initiad
version: v0.1.1-beta.7

$ initiad init [moniker] --chain-id stone-11
$ wget https://initia.s3.ap-southeast-1.amazonaws.com/stone-11/genesis.json
$ cp genesis.json ~/.initia/config/genesis.json

# This will prevent continuous reconnection try. (default P2P_PORT is 26656)
$ sed -i -e 's/external_address = \"\"/external_address = \"'$(curl httpbin.org/ip | jq -r .origin)':26656\"/g' ~/.initia/config/config.toml

$ initiad start
```

## How to setup validator

### Validator Creation

```sh
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

```sh
76e3dcad1aea0f0da362894129ff91fa8da724e1@35.240.145.14:26656
0bf7b685bc9b613c0e3aba23cd03b96de994e698@34.87.95.170:26656
```
