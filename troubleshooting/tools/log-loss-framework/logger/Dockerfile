FROM alpine:3 as build-env

RUN apk add --no-cache build-base

WORKDIR /usr/local/src
COPY log_generator.c /usr/local/src/log_generator.c

RUN gcc -o logger log_generator.c

FROM alpine:3

COPY --from=build-env /usr/local/src/logger /usr/local/bin/logger

CMD ["/usr/local/bin/logger"]
