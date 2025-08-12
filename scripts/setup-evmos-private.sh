#!/usr/bin/env bash
set -euo pipefail

# Private Evmos network setup with premine; prints validator private key

# Defaults (override via env or flags)
CHAIN_ID=${CHAIN_ID:-yo-private-1}
MONIKER=${MONIKER:-yo-validator}
DENOM=${DENOM:-yo}              # requested denom (may be 2-char symbol)
DECIMALS=${DECIMALS:-18}        # display decimals for conversion
PREMINE=${PREMINE:-}            # atomic units (optional if PREMINE_YO provided)
PREMINE_YO=${PREMINE_YO:-}      # display units; converted using DECIMALS
STAKE=${STAKE:-}                # atomic units (optional if STAKE_YO provided)
STAKE_YO=${STAKE_YO:-}          # display units; converted using DECIMALS
MIN_GAS_PRICE=${MIN_GAS_PRICE:-0.0001}
RPC_PORT=${RPC_PORT:-8555}
WS_PORT=${WS_PORT:-8556}
GRPC_PORT=${GRPC_PORT:-9090}
HOME_DIR=${HOME_DIR:-$(pwd)}
KEYRING=${KEYRING:-test}
EVMOS_VERSION=${EVMOS_VERSION:-v20.0.0}

usage() {
  cat <<USAGE
Usage: CHAIN_ID=yo-private-1 DENOM=yo PREMINE=1000000000 STAKE=1 ./scripts/setup-evmos-private.sh

Environment overrides:
  CHAIN_ID, MONIKER, DENOM, PREMINE, STAKE, MIN_GAS_PRICE, RPC_PORT, WS_PORT, GRPC_PORT, HOME_DIR, KEYRING, EVMOS_VERSION
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi

echo "[i] Setting up private Evmos network"
echo "    CHAIN_ID=${CHAIN_ID} MONIKER=${MONIKER} DENOM=${DENOM}"
echo "    HOME_DIR=${HOME_DIR}"

mkdir -p "${HOME_DIR}"
cd "${HOME_DIR}"

# Dependencies
if ! command -v jq >/dev/null 2>&1; then
  echo "[i] Installing jq"
  if command -v apt-get >/dev/null 2>&1; then sudo apt-get update -y && sudo apt-get install -y jq; else echo "[!] Please install jq"; exit 1; fi
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "[i] Installing curl"
  if command -v apt-get >/dev/null 2>&1; then sudo apt-get update -y && sudo apt-get install -y curl; else echo "[!] Please install curl"; exit 1; fi
fi

# Install evmosd if missing
if ! command -v evmosd >/dev/null 2>&1; then
  echo "[i] Installing evmosd ${EVMOS_VERSION}"
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64) TARBALL="evmos_20.0.0_Linux_amd64.tar.gz" ;;
    aarch64|arm64) TARBALL="evmos_20.0.0_Linux_arm64.tar.gz" ;;
    *) echo "[!] Unsupported arch: $ARCH"; exit 1 ;;
  esac
  TMP=$(mktemp -d)
  pushd "$TMP" >/dev/null
  curl -fsSL -O "https://github.com/evmos/evmos/releases/download/${EVMOS_VERSION}/${TARBALL}"
  tar -xzf "$TARBALL"
  EVB=$(find . -type f -name evmosd | head -n1)
  sudo install -m 0755 "$EVB" /usr/local/bin/evmosd
  popd >/dev/null
  rm -rf "$TMP"
fi

echo "[i] evmosd version: $(evmosd version 2>/dev/null || echo unknown)"

echo "[!] This will wipe ${HOME_DIR}/config and ${HOME_DIR}/data"
rm -rf ./config ./data ./keyring-${KEYRING} || true

# Compute base denom compliant with Cosmos (>=3 chars, lowercase)
BASE_DENOM="$DENOM"
if [ ${#BASE_DENOM} -lt 3 ]; then
  BASE_DENOM="a${BASE_DENOM}"
  echo "[i] DENOM too short; using base denom: ${BASE_DENOM}"
fi
BASE_DENOM=$(echo "$BASE_DENOM" | tr '[:upper:]' '[:lower:]')

# Convert premine/stake to atomic if display amounts provided
to_atomic() {
  local display="$1"; local decimals="$2"
  python3 - "$display" "$decimals" <<'PY' 2>/dev/null || echo ""
import sys, decimal
decimal.getcontext().prec = 80
amt = decimal.Decimal(sys.argv[1])
dec = int(sys.argv[2])
q = (amt * (decimal.Decimal(10) ** dec)).to_integral_exact(rounding=decimal.ROUND_DOWN)
print(str(q))
PY
}

if [ -n "${PREMINE_YO}" ]; then
  PREMINE_ATOMIC=$(to_atomic "$PREMINE_YO" "$DECIMALS")
else
  PREMINE_ATOMIC="$PREMINE"
fi
if [ -z "${PREMINE_ATOMIC}" ]; then echo "[!] PREMINE or PREMINE_YO required"; exit 1; fi

if [ -n "${STAKE_YO}" ]; then
  STAKE_ATOMIC=$(to_atomic "$STAKE_YO" "$DECIMALS")
else
  STAKE_ATOMIC="$STAKE"
fi
if [ -z "${STAKE_ATOMIC}" ]; then echo "[!] STAKE or STAKE_YO required"; exit 1; fi

echo "    Premine (atomic): ${PREMINE_ATOMIC} ${BASE_DENOM}"
echo "    Stake   (atomic): ${STAKE_ATOMIC} ${BASE_DENOM}"

# Initialize chain
evmosd init "$MONIKER" --chain-id "$CHAIN_ID" --home .
evmosd config chain-id "$CHAIN_ID" --home .
evmosd config keyring-backend "$KEYRING" --home .
evmosd config node tcp://localhost:26657 --home .

# Create validator key (capture mnemonic) if missing
MNEMONIC_JSON=$(evmosd keys add validator --keyring-backend "$KEYRING" --home . --output json 2>/dev/null || true)
if [[ -z "$MNEMONIC_JSON" ]]; then
  # already exists, export mnemonic unavailable; proceed
  echo "[i] Validator key already exists"
else
  VALIDATOR_MNEMONIC=$(echo "$MNEMONIC_JSON" | jq -r '.mnemonic')
fi
VAL_ADDR=$(evmosd keys show validator --keyring-backend "$KEYRING" --home . --address)
echo "[i] Validator address: $VAL_ADDR"

# Premine and denom updates
evmosd add-genesis-account "$VAL_ADDR" "${PREMINE_ATOMIC}${BASE_DENOM}" --home .

# Patch genesis denoms to $DENOM
export BASE_DENOM
jq '.app_state.staking.params.bond_denom = env.BASE_DENOM
  | .app_state.crisis.constant_fee.denom = env.BASE_DENOM
  | (.app_state.gov.params.min_deposit // []) |= (map(.denom = env.BASE_DENOM))
  | (.app_state.gov.params.expedited_min_deposit // []) |= (map(.denom = env.BASE_DENOM))
  | .app_state.inflation.params.mint_denom = env.BASE_DENOM
  | .app_state.evm.params.evm_denom = env.BASE_DENOM' config/genesis.json > config/genesis.json.tmp
mv config/genesis.json.tmp config/genesis.json

# Create gentx and collect
evmosd gentx validator "${STAKE_ATOMIC}${BASE_DENOM}" --chain-id "$CHAIN_ID" --moniker "$MONIKER" --keyring-backend "$KEYRING" --home . --yes
evmosd collect-gentxs --home .
evmosd validate-genesis --home .

# Ensure priv_validator_state.json exists
mkdir -p data
echo '{}' > data/priv_validator_state.json

# Tweak app.toml: min gas price and archive pruning
APP=config/app.toml
sed -i "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"${MIN_GAS_PRICE}${BASE_DENOM}\"|" "$APP" || true
sed -i "s|^pruning *=.*|pruning = \"nothing\"|" "$APP" || true
grep -q '^pruning-keep-recent' "$APP" || echo 'pruning-keep-recent = "0"' >> "$APP"
grep -q '^pruning-interval' "$APP" || echo 'pruning-interval = "0"' >> "$APP"

# Export validator private key (hex, unsafe) and show mnemonic if we have it
echo
echo "================= Validator Keys ================="
set +e
PRIV_HEX=$(evmosd keys export validator --keyring-backend "$KEYRING" --home . --unarmored-hex --unsafe 2>/dev/null)
set -e
if [[ -n "${PRIV_HEX:-}" ]]; then
  echo "Private key (hex, unsafe): $PRIV_HEX"
else
  echo "Private key export not available on this build."
fi
if [[ -n "${VALIDATOR_MNEMONIC:-}" ]]; then
  echo "Mnemonic: $VALIDATOR_MNEMONIC"
else
  echo "Mnemonic: (not captured; key pre-existed)"
fi
echo "Address: $VAL_ADDR"
echo "=================================================="

echo
echo "[i] Setup complete. To start the node run:"
echo "evmosd start \\
  --home . \\
  --chain-id ${CHAIN_ID} \\
  --minimum-gas-prices=${MIN_GAS_PRICE}${DENOM} \\
  --json-rpc.enable \\
  --json-rpc.api eth,txpool,personal,net,debug,web3 \\
  --json-rpc.address 0.0.0.0:${RPC_PORT} \\
  --json-rpc.ws-address 0.0.0.0:${WS_PORT} \\
  --rpc.laddr tcp://0.0.0.0:26657 \\
  --p2p.laddr tcp://0.0.0.0:26656 \\
  --iavl-disable-fastnode=true"
