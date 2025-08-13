FROM ghcr.io/foundry-rs/foundry:nightly

WORKDIR /app

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y curl build-essential && \
    rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Setup Rust environment and install cargo tools
RUN . ~/.cargo/env && cargo install rust-script

ENV PATH="/root/.cargo/bin:${PATH}"

COPY . .

# Build Foundry contracts
RUN forge soldeer update
RUN forge build
RUN forge test

# Make utility scripts executable
RUN chmod +x .github/scripts/contract-deployer.rs

ENTRYPOINT ["forge"]

CMD ["--version"]
