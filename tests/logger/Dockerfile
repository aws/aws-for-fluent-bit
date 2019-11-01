FROM alpine

# Update package index and install go + git
RUN apk add --update go git bash libc-dev

# Set up GOPATH
RUN mkdir /go
ENV GOPATH /go

RUN go get github.com/mingrammer/flog
WORKDIR /go/src/github.com/mingrammer/flog
RUN go install

ADD logscript.sh /
WORKDIR /
RUN chmod +x /logscript.sh
ENTRYPOINT ["/logscript.sh"]
