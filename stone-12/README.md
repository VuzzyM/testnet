# Stone-11

Testnet for Initia.

- The genesis event for Stone-12 testnet started at **2023-11-21T09:34:46.620342767Z (UTC)**

## Binaries

| height  | link  |
| ------- | ----- |
| 0~      | [initia@v0.1.2-beta.5](https://github.com/initia-labs/initia/releases/tag/v0.1.2-beta.5) |

## Prerequisites

- Go v1.19+ or higher
- Git
- curl
- jq

## How to Setup

Install binaries from [here](./binaries/) or you can install from the [source code](https://github.com/initia-labs/initia).

Download the genesis from [here](https://initia.s3.ap-southeast-1.amazonaws.com/stone-12/genesis.json).

```shell
# you can install initiad from the s3
# $ wget https://initia.s3.ap-southeast-1.amazonaws.com/stone-12/initia_0.1.2-beta.5_Darwin_aarch64.tar.gz
# $ wget https://initia.s3.ap-southeast-1.amazonaws.com/stone-12/initia_0.1.2-beta.5_Linux_x86_64.tar.gz

# or, build from the source
$ git clone https://github.com/initia-labs/initia
$ git checkout v0.1.2-beta.5
$ make install

$ initiad version --long
build_tags: netgo,ledger
commit: 3f62290b17b48c47a30bac135268aa55b45add0d
cosmos_sdk_version: v0.47.5
go: go version go1.20.6 darwin/arm64
name: initia
server_name: initiad
version: v0.1.2-beta.5

$ initiad init [moniker] --chain-id stone-12
$ wget https://initia.s3.ap-southeast-1.amazonaws.com/stone-12/genesis.json
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
37285b908777add4a190cf503cec38c10e32c1ad@34.126.188.182:26656
8aff8440d6a1cc3f64ef03180f2125198b679b34@34.87.48.236:26656
```
