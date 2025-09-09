FROM ghcr.io/foundry-rs/foundry:stable

WORKDIR /app
USER root

# Install system dependencies
RUN apt-get update && apt-get install -y curl build-essential && rm -rf /var/lib/apt/lists/*
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN . ~/.cargo/env && cargo install rust-script

ENV PATH="/root/.cargo/bin:${PATH}"

COPY . .

# Setup scripts and configs
RUN mkdir /scripts && \
    cp .github/scripts/protocol-cli.rs .github/scripts/deployment-config.yaml /scripts/ && \
    chmod +x /scripts/protocol-cli.rs

# Build contracts and run tests
RUN forge soldeer update
RUN forge build
RUN forge test

ENTRYPOINT ["forge"]
CMD ["--version"]
