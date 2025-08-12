#!/bin/sh
set -e

# Ensure standard paths
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

EVMOSD=${EVMOSD:-/usr/local/bin/evmosd}
HOME_DIR=${HOME_DIR:-/root/.evmosd}
CHAIN_ID=${CHAIN_ID:-yo_100892-1}
MONIKER=${MONIKER:-yo-validator}
BASE_DENOM=${BASE_DENOM:-ayo}
PREMINE=${PREMINE:-1000000000000000000000000000}
VALIDATOR_STAKE=${VALIDATOR_STAKE:-1000000000000000000}
RPC_PORT=${RPC_PORT:-8555}
WS_PORT=${WS_PORT:-8556}

mkdir -p "$HOME_DIR"
cd "$HOME_DIR"
echo "[i] PATH=$PATH"
echo "[i] Checking evmosd availability..."
if [ -x "$EVMOSD" ]; then
  echo "[i] evmosd found at: $EVMOSD"
else
  echo "[i] evmosd not executable or missing at: $EVMOSD"
fi

# Fallback: install evmosd if missing in the image
if [ ! -x "$EVMOSD" ]; then
  echo "[!] evmosd not found in image; attempting inline install (linux_amd64 v20.0.0)"
  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache curl tar ca-certificates >/dev/null 2>&1 || true
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y --no-install-recommends curl tar ca-certificates >/dev/null 2>&1 || true
  fi
  mkdir -p /tmp/evmos && cd /tmp/evmos
  if curl -fsSL -o evmos.tar.gz https://github.com/evmos/evmos/releases/download/v20.0.0/evmos_20.0.0_Linux_amd64.tar.gz; then
    tar -xzf evmos.tar.gz || true
    FOUND=$(find . -type f -name evmosd | head -n1)
    if [ -n "$FOUND" ]; then
      cp "$FOUND" "$EVMOSD" && chmod +x "$EVMOSD"
      echo "[+] evmosd installed to /usr/local/bin/evmosd"
    else
      echo "[!] evmosd binary not found in archive"
    fi
  else
    echo "[!] Failed to download evmosd archive"
  fi
  cd "$HOME_DIR"
fi

# Final sanity check
if [ ! -x "$EVMOSD" ]; then
  echo "[x] evmosd still not on PATH; aborting"
  ls -l /usr/local/bin || true
  exit 1
fi
if ! "$EVMOSD" version >/dev/null 2>&1; then
  echo "[x] evmosd present but not executable; aborting"
  file "$EVMOSD" || true
  ldd "$EVMOSD" || true
  exit 1
fi
echo "[i] evmosd version: $($EVMOSD version 2>/dev/null | head -n 1)"

if [ ! -f "$HOME_DIR/config/genesis.json" ]; then
  echo "[*] First run: initializing chain $CHAIN_ID"
  $EVMOSD init "$MONIKER" --chain-id "$CHAIN_ID" --home "$HOME_DIR"

  # Configure client
  $EVMOSD config chain-id "$CHAIN_ID" --home "$HOME_DIR"
  $EVMOSD config keyring-backend test --home "$HOME_DIR"
  $EVMOSD config node tcp://localhost:26657 --home "$HOME_DIR"

  # Keys and fund genesis account
  if ! $EVMOSD keys show validator --keyring-backend test --home "$HOME_DIR" >/dev/null 2>&1; then
    echo "" | $EVMOSD keys add validator --keyring-backend test --home "$HOME_DIR" >/dev/null
  fi
  VAL_ADDR=$($EVMOSD keys show validator --keyring-backend test --home "$HOME_DIR" --address)
  $EVMOSD add-genesis-account "$VAL_ADDR" "${PREMINE}${BASE_DENOM}" --home "$HOME_DIR"

  # Adjust genesis denoms to BASE_DENOM using sed (no Python dependency)
  sed -i "s/\"aevmos\"/\"${BASE_DENOM}\"/g" "$HOME_DIR/config/genesis.json" || true
  sed -i "s/\"ayomlm\"/\"${BASE_DENOM}\"/g" "$HOME_DIR/config/genesis.json" || true

  # Create gentx and collect
  $EVMOSD gentx validator "${VALIDATOR_STAKE}${BASE_DENOM}" --chain-id "$CHAIN_ID" --keyring-backend test --home "$HOME_DIR" --moniker "$MONIKER" --yes
  $EVMOSD collect-gentxs --home "$HOME_DIR"
fi

# Ensure priv_validator_state.json exists
mkdir -p "$HOME_DIR/data"
[ -f "$HOME_DIR/data/priv_validator_state.json" ] || echo '{}' > "$HOME_DIR/data/priv_validator_state.json"

# Ensure app.toml exists; if it already exists, update minimal keys in-place
if [ ! -f "$HOME_DIR/config/app.toml" ]; then
  cat > "$HOME_DIR/config/app.toml" <<EOF
minimum-gas-prices = "0.0001${BASE_DENOM}"
pruning = "nothing"
pruning-keep-recent = "0"
pruning-interval = "0"
min-retain-blocks = 0

[json-rpc]
enable = true
address = "0.0.0.0:${RPC_PORT}"
ws-address = "0.0.0.0:${WS_PORT}"
api = "eth,txpool,personal,net,debug,web3"

[grpc]
enable = true
address = "0.0.0.0:9090"

[state-sync]
snapshot-interval = 1000
snapshot-keep-recent = 2
EOF
else
  sed -i "s/^minimum-gas-prices.*/minimum-gas-prices = \"0.0001${BASE_DENOM}\"/" "$HOME_DIR/config/app.toml" || true
  sed -i "s/^pruning = .*/pruning = \"nothing\"/" "$HOME_DIR/config/app.toml" || true
  # Update JSON-RPC section addresses if present
  sed -i "s/^address = \"0.0.0.0:.\+\"/address = \"0.0.0.0:${RPC_PORT}\"/" "$HOME_DIR/config/app.toml" || true
  sed -i "s/^ws-address = \"0.0.0.0:.\+\"/ws-address = \"0.0.0.0:${WS_PORT}\"/" "$HOME_DIR/config/app.toml" || true
fi

# Write config.toml overrides: iavl-disable-fastnode=true and rpc/p2p binds
# Note: iavl-disable-fastnode is an app flag in Evmos; we pass it via start args

exec $EVMOSD start \
  --home "$HOME_DIR" \
  --chain-id "$CHAIN_ID" \
  --minimum-gas-prices "0.0001${BASE_DENOM}" \
  --json-rpc.api eth,txpool,personal,net,debug,web3 \
  --json-rpc.enable \
  --json-rpc.address 0.0.0.0:${RPC_PORT} \
  --json-rpc.ws-address 0.0.0.0:${WS_PORT} \
  --rpc.laddr tcp://0.0.0.0:26657 \
  --p2p.laddr tcp://0.0.0.0:26656 \
  --iavl-disable-fastnode=true
