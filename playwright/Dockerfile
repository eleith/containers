FROM mcr.microsoft.com/playwright:v1.61.1-noble

ARG NODE_VERSION=26
ARG PNPM_VERSION=11.9.0

# The base image ships Node 24 from nodesource; this replaces that same package.
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		gnupg \
	&& curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs \
	&& rm -f /usr/bin/yarn /usr/bin/yarnpkg /usr/bin/pnpm /usr/bin/pnpx /usr/bin/corepack \
	&& npm install --global corepack@latest \
	&& corepack enable \
	&& corepack prepare "pnpm@${PNPM_VERSION}" --activate \
	&& DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove gnupg \
	&& rm -rf /var/lib/apt/lists/*

RUN node --version && pnpm --version
