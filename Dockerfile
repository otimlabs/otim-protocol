FROM ghcr.io/foundry-rs/foundry:nightly

WORKDIR /app

USER root

COPY . .

RUN forge soldeer update
RUN forge build
RUN forge test

ENTRYPOINT ["forge"]

CMD ["--version"]
