# Stone-1

Testnet for Initia.

[initia@v0.1.0-beta.13](https://github.com/initia-labs/initia/releases/tag/v0.1.0-beta.13) should be used to run the testnet.

- The genesis event for Stone-1 testnet will occur **2023-04-XXT06:00:00Z (UTC)**

## Prerequisites
* Go v1.19+ or higher
* Git
* curl
* jq

## How to Setup

```shell
$ git clone https://github.com/initia-labs/initia
$ git checkout v0.1.0-beta.13
$ make install

$ initiad version --long
name: initia
server_name: initiad
version: v0.1.0-beta.13
commit: 0efc36199ee34304092a50f431680ea45ae33c23
build_tags: netgo,ledger
go: go version go1.19.3 darwin/arm64

$ initiad init [moniker] --chain-id stone-1
$ wget https://initia.s3.ap-southeast-1.amazonaws.com/stone-7/genesis.json
$ cp genesis.json ~/.initia/config/genesis.json

# This will prevent continuous reconnection try. (default P2P_PORT is 26656)
$ sed -i -e 's/external_address = \"\"/external_address = \"'$(curl httpbin.org/ip | jq -r .origin)':26656\"/g' ~/.initia/config/config.toml

$ initiad start
```

### Seed Nodes
```
c08d5b3d253bea18b24593a894a0aa6e168079d3@34.232.34.124:26656
```

### Known Peers
```
a4a8fbd7d26242263250a1d3ecb39f113832534b@52.73.183.21:26656
3a4c8f4d75781f39b558c3889157acfaa144a793@50.19.18.17:26656
```
