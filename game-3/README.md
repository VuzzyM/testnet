# game-3

Testnet for Initia.

- The genesis event for game-3 testnet started at **2023-11-22T06:19:37.517191559Z (UTC)**

## Binaries

| height  | link  |
| ------- | ----- |
| 0~      | [testnet/game-3](https://github.com/initia-labs/minimove/tree/testnet/game-3) |

## Prerequisites

- Go v1.19+ or higher
- Git
- curl
- jq

## How to Setup

Install binaries from [here](./binaries/) or you can install from the [source code](https://github.com/initia-labs/miniwasm/tree/testnet/game-3).

Download the genesis from [here](https://initia.s3.ap-southeast-1.amazonaws.com/game-3/genesis.json).

```shell
# you can install minitiad from the s3
# $ wget https://initia.s3.ap-southeast-1.amazonaws.com/game-3/game-3_Linux_x86_64.tar.gz

# or, build from the source
$ git clone https://github.com/initia-labs/minimove
$ git switch testnet/game-3
$ make install

$ minitiad version --long
build_tags: netgo ledger,
commit: d124fa842c34b6ba466a8b3793d9f54960fd697e
cosmos_sdk_version: v0.47.5
go: go version go1.21.4 linux/amd64
name: minitia
server_name: minitiad
version: v0.1.0-beta.4-2-gd124fa8

$ minitiad init [moniker] --chain-id game-3
$ wget https://initia.s3.ap-southeast-1.amazonaws.com/game-3/genesis.json
$ cp genesis.json ~/.minitia/config/genesis.json

# This will prevent continuous reconnection try. (default P2P_PORT is 26656)
$ sed -i -e 's/external_address = \"\"/external_address = \"'$(curl httpbin.org/ip | jq -r .origin)':26656\"/g' ~/.initia/config/config.toml

$ minitiad start
```

### Known Peers

```sh
de1274c5cf2de42312a194fef6f8274d389e63cf@34.126.179.162:26656
```
