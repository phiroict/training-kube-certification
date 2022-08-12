##
# We take the latest version of the rust stack as rust is pretty hot on backward compatibility so we are not too
# concerned about that. We do get the latest fixes this way. Note that is different strategy than the runner below, we
# keep that on a fixed version. OS changes are not guaranteed backwards compatible so we are stricter there.
##
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

# ## We take a fixed version of debian here, note that these version need to be updated often as security flaws may have been fixed,
#    As we want to control changes, we change this once a month (or on secuity issues) with no changes in the source
#    so we can isolate changes in the stack)
# ##
FROM debian:sid-20220801-slim
# Redeclare the argument anew as it is erased after a FROM statement. 
ARG app_name
# ## Using reqwest lib in rust needs the libssl version 1.1 - Note we add it for all now though strictly this is not needed for all.
# Note we do not update the whole distro as that may introduce changes we do not want.
RUN apt update && apt install libssl1.1
# ## Install the application and the configuration file that Rocker (The web framework in Rust) needs it.
COPY --from=builder /app/$app_name/target/release/$app_name /
COPY --from=builder /app/$app_name/Rocket.toml Rocket.toml
RUN echo "Value of app $app_name"
RUN chmod +x ./$app_name
# The ARG will not persist in docker runs, so you need to assign it to an environment var. 
ENV EXECUTABLE ${app_name} 
CMD ./$EXECUTABLE