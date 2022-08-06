FROM rust:latest as builder
# Arguments, not that it needs to follow the FROM statement and will be reset at the next FROM!
ARG path
ARG app_name

RUN mkdir /app
COPY ./$path /app
WORKDIR /app/$app_name
RUN ls -l 
RUN rustup override set nightly && 	cargo install cargo-release && 	rustup component add clippy && 	rustup component add rustfmt
RUN cargo build --release

FROM debian:sid-20220801-slim
# Redeclare the argument anew as it is erased after a FROM statement. 
ARG app_name
COPY --from=builder /app/$app_name/target/release/$app_name /
COPY --from=builder /app/$app_name/Rocket.toml Rocket.toml
RUN echo "Value of app $app_name"
RUN chmod +x ./$app_name
# The ARG will not persist in docker runs, so you need to assign it to an environment var. 
ENV EXECUTABLE ${app_name} 
CMD ./$EXECUTABLE