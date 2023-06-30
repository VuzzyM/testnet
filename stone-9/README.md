# Stone-1

Testnet for Initia.

- The genesis event for Stone-9 testnet started at **2023-06-23T03:05:37.169946746Z (UTC)**

## Binaries

| height  | link  |
| ------- | ----- |
| 0~12000 | [initia@v0.1.0-beta.20](https://github.com/initia-labs/initia/releases/tag/v0.1.0-beta.20) |
| 120000~ | [initia@v0.1.0-beta.21](https://github.com/initia-labs/initia/releases/tag/v0.1.0-beta.21) |

## Prerequisites

- Go v1.19+ or higher
- Git
- curl
- jq

## How to Setup

Install binaries from [here](./binaries/) or you can install from the [source code](https://github.com/initia-labs/initia).

Download the genesis from [here](https://initia.s3.ap-southeast-1.amazonaws.com/stone-9/genesis.json).

```shell
# you can install initiad from the s3
# $ wget https://stone-9.s3.ap-southeast-1.amazonaws.com/initia_0.1.0-beta.20_Linux_x86_64.tar.gz
# $ wget https://stone-9.s3.ap-southeast-1.amazonaws.com/initia_0.1.0-beta.20_Darwin_aarch64.tar.gz
# $ wget https://stone-9.s3.ap-southeast-1.amazonaws.com/initia_0.1.0-beta.21_Linux_x86_64.tar
# $ wget https://stone-9.s3.ap-southeast-1.amazonaws.com/initia_0.1.0-beta.21_Darwin_aarch64.tar.gz

# or, build from the source
$ git clone https://github.com/initia-labs/initia
$ git checkout v0.1.0-beta.20
$ make install

$ initiad version --long
build_tags: netgo ledger,
commit: 4c091d84acf4bf276b03d6824acf3ae5cee40fbf
cosmos_sdk_version: v0.47.3
go: go version go1.19.5 linux/amd64
name: initia
server_name: initiad
version: v0.1.0-beta.20

$ initiad init [moniker] --chain-id stone-9
$ wget https://stone-9.s3.ap-southeast-1.amazonaws.com/genesis.json
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
11475272221bc0efa79ffbf0f2e5dfdc40b08900@52.221.241.54:26656
```
