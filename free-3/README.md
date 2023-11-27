# free-3

Testnet for Initia.

- The genesis event for free-3 testnet started at **2023-11-22T10:40:52.5236745Z (UTC)**

## Binaries

| height  | link  |
| ------- | ----- |
| 0~      | [testnet/free-3](https://github.com/initia-labs/minimove/tree/testnet/free-3) |

## Prerequisites

- Go v1.19+ or higher
- Git
- curl
- jq

## How to Setup

Install binaries from [here](./binaries/) or you can install from the [source code](https://github.com/initia-labs/minimove/tree/testnet/free-3).

Download the genesis from [here](https://initia.s3.ap-southeast-1.amazonaws.com/free-3/genesis.json).

```shell
# you can install minitiad from the s3
# $ wget https://initia.s3.ap-southeast-1.amazonaws.com/free-3/free-3_Linux_x86_64.tar.gz

# or, build from the source
$ git clone https://github.com/initia-labs/minimove
$ git switch testnet/free-3
$ make install

$ minitiad version --long
build_tags: netgo ledger,
commit: e28d950f306e6fa95fba77548393951eddd5f8a8
cosmos_sdk_version: v0.47.6
go: go version go1.21.4 linux/amd64
name: minitia
server_name: minitiad
version: v0.1.0-beta.4-7-ge28d950

$ minitiad init [moniker] --chain-id free-3
$ wget https://initia.s3.ap-southeast-1.amazonaws.com/free-3/genesis.json
$ cp genesis.json ~/.minitia/config/genesis.json

# This will prevent continuous reconnection try. (default P2P_PORT is 26656)
$ sed -i -e 's/external_address = \"\"/external_address = \"'$(curl httpbin.org/ip | jq -r .origin)':26656\"/g' ~/.initia/config/config.toml

$ minitiad start
```

### Known Peers

```sh
6399de72633ebd55146a3d5f394535d8d68461fa@34.126.152.13:26656
```
