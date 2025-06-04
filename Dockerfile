FROM ghcr.io/foundry-rs/foundry:nightly

WORKDIR /app

COPY . .

RUN forge build
RUN forge test

ENTRYPOINT ["forge"]

CMD ["--version"]
