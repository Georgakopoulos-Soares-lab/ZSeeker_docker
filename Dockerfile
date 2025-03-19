# Stage 1: Build the Go backend
FROM golang:1.23 as builder
WORKDIR /app

# Copy Go module files first to cache dependencies
COPY zseeker_back/go.mod zseeker_back/go.sum ./go_back/
WORKDIR /app/go_back
RUN go mod download

# Copy the rest of the Go backend source code and build the server binary
COPY zseeker_back/ .
RUN go build -o server server.go

# Stage 2: Create final image with both Go backend and Python CLI
FROM python:3.10-slim

# Install Python 3 and pip, along with any other required packages
RUN apt-get update && \
    apt-get install -y python3 python3-pip ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the built Go server binary from the builder stage
COPY --from=builder /app/go_back/server /app/server

# Copy the Python CLI package code
COPY ZSeeker/ /app/ZSeeker/

# Install the Python CLI package in editable mode so that its entrypoint is available (assumes setup.py defines a script "ZSeeker")
RUN pip3 install --upgrade pip && pip3 install -e /app/ZSeeker

# Expose the port used by your Go server
EXPOSE 8080

# Run the Go server. It can now call the CLI using the command "ZSeeker" (which should be in /usr/local/bin)
CMD ["/app/server"]
