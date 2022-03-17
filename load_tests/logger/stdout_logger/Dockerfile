FROM alpine as build-env

RUN apk add --no-cache build-base

WORKDIR /app

COPY . .

RUN gcc -o logger log_generator.c

FROM alpine

COPY --from=build-env /app/logger /app/logger

WORKDIR /app

CMD ["/app/logger"] 