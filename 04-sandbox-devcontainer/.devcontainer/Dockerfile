# =============================================================================
#  OpenCode sandbox image - OPTIONAL tier (stronger isolation)
#  Pull base images / packages from your INTERNAL registry mirrors.
# =============================================================================
ARG BASE_IMAGE=<INTERNAL_REGISTRY>/library/node:22-bookworm-slim
FROM ${BASE_IMAGE}

# OpenCode 2.x is published as @opencode/cli (opencode-ai still ships 1.x)
ARG OPENCODE_PACKAGE=@opencode/cli
ARG OPENCODE_VERSION=<PINNED_OPENCODE_2_VERSION>
ARG NPM_REGISTRY=<INTERNAL_NPM_MIRROR_URL>

RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates iptables ipset dnsutils sudo procps less \
    && rm -rf /var/lib/apt/lists/*

# Corporate CA (TLS interception / internal PKI)
COPY corporate-ca.pem /usr/local/share/ca-certificates/corporate-ca.crt
RUN update-ca-certificates
ENV NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/corporate-ca.crt

# Pinned OpenCode from the internal npm mirror
RUN npm config set registry "${NPM_REGISTRY}" \
 && npm install -g "${OPENCODE_PACKAGE}@${OPENCODE_VERSION}" \
 && npm cache clean --force

# Hardened config at the MANAGED path (root-owned, read-only for the agent user)
COPY opencode.json /etc/opencode/opencode.json
RUN chmod 644 /etc/opencode/opencode.json && chown root:root /etc/opencode/opencode.json

# Firewall script: only root may run it, the agent user may run ONLY this via sudo
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod 755 /usr/local/bin/init-firewall.sh \
 && echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/firewall \
 && chmod 0440 /etc/sudoers.d/firewall

ENV OPENCODE_DISABLE_SHARE=1 \
    OPENCODE_DISABLE_AUTOUPDATE=1 \
    OPENCODE_DISABLE_MODELS_FETCH=1 \
    OPENCODE_DISABLE_LSP_DOWNLOAD=1 \
    OC_SANDBOX=1

USER node
WORKDIR /workspace
