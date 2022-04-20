# Start from the latest golang base image
FROM public.ecr.aws/amazonlinux/amazonlinux:latest
RUN curl -sL -o /bin/gimme https://raw.githubusercontent.com/travis-ci/gimme/master/gimme
RUN chmod +x /bin/gimme
RUN yum upgrade -y && yum install -y tar gzip git
ENV HOME /home
RUN /bin/gimme 1.17.9
ENV PATH ${PATH}:/home/.gimme/versions/go1.17.9.linux.arm64/bin:/home/.gimme/versions/go1.17.9.linux.amd64/bin
RUN go version
ENV GOPROXY=direct

# Set the Current Working Directory inside the container
WORKDIR /app

# Copy the source from the current directory to the Working Directory inside the container
COPY . .

# Download all dependencies. Dependencies will be cached if the go.mod and go.sum files are not changed
RUN go mod download

# Build the Go app
RUN go build -o s3ValidateAndClean .

# Command to run the executable
CMD ["./s3ValidateAndClean"]
