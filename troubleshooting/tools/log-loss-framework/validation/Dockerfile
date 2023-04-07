FROM alpine:3 as build-env

RUN apk update && apk add --no-cache go git

WORKDIR /usr/local/src
RUN go mod init validate && go env -w GOPROXY=direct && \
    go get github.com/aws/aws-sdk-go/aws && \
    go get github.com/aws/aws-sdk-go/aws/session && \
    go get github.com/aws/aws-sdk-go/service/cloudwatchlogs && \
    go get github.com/aws/aws-sdk-go/service/s3

COPY validate.go /usr/local/src/validate.go
RUN CGO_ENABLED=0 GOOS=linux go build -o validation

FROM alpine:3

COPY --from=build-env /usr/local/src/validation /usr/local/bin/validation

CMD ["/usr/local/bin/validation", "10", "10"]
