FROM golang:1.22-bookworm AS builder

ARG EVMOS_VERSION=v20.0.0

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    git make build-essential ca-certificates && update-ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --branch ${EVMOS_VERSION} --depth 1 https://github.com/evmos/evmos.git .
RUN make build || make build-linux || true
# Copy built evmosd
RUN set -eux; \
    BIN=$(find build -maxdepth 1 -type f -name evmosd 2>/dev/null | head -n1 || true); \
    if [ -z "$BIN" ]; then BIN=$(find . -type f -name evmosd 2>/dev/null | head -n1 || true); fi; \
    if [ -z "$BIN" ]; then echo "evmosd binary not found after build"; exit 1; fi; \
    install -m 0755 "$BIN" /usr/local/bin/evmosd; \
    /usr/local/bin/evmosd version || true

FROM debian:bookworm-slim
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    ca-certificates jq curl sed bash && update-ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/evmosd /usr/local/bin/evmosd
COPY scripts/docker-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 26656 26657 9090 8555 8556

ENTRYPOINT ["/bin/sh", "/usr/local/bin/entrypoint.sh"]
