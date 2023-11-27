# wasm-3

Testnet for Initia.

- The genesis event for wasm-3 testnet started at **2023-11-22T06:51:53.966759779Z (UTC)**

## Binaries

| height  | link  |
| ------- | ----- |
| 0~      | [testnet/wasm-3](https://github.com/initia-labs/miniwasm/tree/testnet/wasm-3) |

## Prerequisites

- Go v1.19+ or higher
- Git
- curl
- jq

## How to Setup

Install binaries from [here](./binaries/) or you can install from the [source code](https://github.com/initia-labs/miniwasm/tree/testnet/wasm-3).

Download the genesis from [here](https://initia.s3.ap-southeast-1.amazonaws.com/wasm-3/genesis.json).

```shell
# you can install minitiad from the s3
# $ wget https://initia.s3.ap-southeast-1.amazonaws.com/wasm-3/wasm-3_Linux_x86_64.tar.gz

# or, build from the source
$ git clone https://github.com/initia-labs/miniwasm
$ git switch testnet/wasm-3
$ make install

$ minitiad version --long
build_tags: netgo ledger,
commit: 56c3c5e4ca530ba85185659547d7ace6962bbb8f
cosmos_sdk_version: v0.47.5
go: go version go1.21.4 linux/amd64
name: minitia
server_name: minitiad
version: v0.1.0-beta.3-2-g56c3c5e

$ minitiad init [moniker] --chain-id wasm-3
$ wget https://initia.s3.ap-southeast-1.amazonaws.com/wasm-3/genesis.json
$ cp genesis.json ~/.minitia/config/genesis.json

# This will prevent continuous reconnection try. (default P2P_PORT is 26656)
$ sed -i -e 's/external_address = \"\"/external_address = \"'$(curl httpbin.org/ip | jq -r .origin)':26656\"/g' ~/.initia/config/config.toml

$ minitiad start
```

### Known Peers

```sh
b03a3fb7368072c4c2a87d216875b6927d404f6a@34.124.240.207:26656
```
