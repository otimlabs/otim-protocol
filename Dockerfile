FROM ghcr.io/foundry-rs/foundry:stable

WORKDIR /app
USER root

# Install system dependencies
RUN apt-get update && apt-get install -y curl jq build-essential && \
    rm -rf /var/lib/apt/lists/*

# Install Rust and set up toolchain
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}" RUSTUP_HOME="/root/.rustup" CARGO_HOME="/root/.cargo"
RUN . ~/.cargo/env && rustup default stable && cargo install rust-script

COPY . .

# Setup deployment scripts
RUN mkdir /scripts && cp .github/deployment/scripts/protocol-cli.rs /scripts/ && \
    chmod +x /scripts/protocol-cli.rs

# Precompile rust-script to cache in image
RUN rust-script /scripts/protocol-cli.rs --help

# Build contracts and run tests
RUN forge soldeer update
RUN forge build
RUN forge test

ENTRYPOINT ["forge"]
CMD ["--version"]
