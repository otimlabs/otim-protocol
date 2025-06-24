FROM ghcr.io/foundry-rs/foundry:nightly

WORKDIR /app

# Create a non-root user and set it as the active user
RUN useradd -m rootuser && chown -R rootuser:rootuser /app
USER rootuser

COPY . .

RUN forge soldeer update
RUN forge build
RUN forge test

ENTRYPOINT ["forge"]

CMD ["--version"]
