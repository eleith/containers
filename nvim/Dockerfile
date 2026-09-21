# debian, not alpine: the upstream nvim release binary is built against glibc and alpine uses musl
FROM debian:13.7-slim

ARG NVIM_VERSION=0.12.1
ARG LUALS_VERSION=3.19.1
ARG STYLUA_VERSION=2.5.2

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		git \
		make \
		unzip \
	&& curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
		| tar xz -C /opt \
	&& mkdir -p /opt/luals \
	&& curl -fsSL "https://github.com/LuaLS/lua-language-server/releases/download/${LUALS_VERSION}/lua-language-server-${LUALS_VERSION}-linux-x64.tar.gz" \
		| tar xz -C /opt/luals \
	&& curl -fsSL -o /tmp/stylua.zip \
		"https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-linux-x86_64.zip" \
	&& unzip -q /tmp/stylua.zip -d /usr/local/bin \
	&& chmod +x /usr/local/bin/stylua \
	&& rm /tmp/stylua.zip \
	&& apt-get purge -y --auto-remove unzip \
	&& rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/nvim-linux-x86_64/bin:/opt/luals/bin:${PATH}"

RUN nvim --version | head -1 && lua-language-server --version && stylua --version
