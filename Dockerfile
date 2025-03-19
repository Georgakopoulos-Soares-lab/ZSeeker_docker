# Stage 1: Build the Go backend
FROM golang:1.23 as builder
WORKDIR /app
# Copy Go module files to leverage caching
COPY zseeker_back/go.mod zseeker_back/go.sum ./go_back/
WORKDIR /app/go_back
RUN go mod download
# Copy all backend source code and build the server binary
COPY zseeker_back/ .
RUN go build -o server server.go

# Stage 2: Prepare the Frontend
FROM nginx:alpine as frontend
# In this stage we simply copy the static files from the frontend repo
WORKDIR /app
COPY zseeker_front/ /usr/share/nginx/html

# Stage 3: Final Image (Single container running both services)
FROM python:3.10-slim
# Install nginx, supervisor, and necessary build tools and certificates.
RUN apt-get update && \
    apt-get install -y nginx supervisor ca-certificates gcc build-essential && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the built Go server binary from Stage 1.
COPY --from=builder /app/go_back/server /app/server

# Copy the Python CLI package (from your ZSeeker repo) and install it.
COPY ZSeeker/ /app/ZSeeker/
RUN pip install --upgrade pip && pip install -e /app/ZSeeker

# Copy the frontend static files from Stage 2.
COPY --from=frontend /usr/share/nginx/html /usr/share/nginx/html

# Remove the default nginx configuration if needed.
RUN rm /etc/nginx/sites-enabled/default

# Copy a custom supervisor configuration that will run both the backend and nginx.
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports: 80 for the frontend and 8080 for the backend.
EXPOSE 80 8080

# Start supervisor in the foreground.
CMD ["/usr/bin/supervisord", "-n"]
