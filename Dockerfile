# Build stage
FROM golang:1.24-alpine AS build

# Install necessary build tools
RUN apk --no-cache add ca-certificates tzdata git

# Set working directory
WORKDIR /app

# Copy only go.mod and go.sum first for better layer caching
COPY ./app/go.mod ./app/go.sum ./

# Download dependencies (will be cached if go.mod/go.sum don't change)
RUN go mod download

# Copy the source code
COPY ./app .

# Run linting and tests
RUN go vet -v ./...
RUN go test -v ./...

# Build the application with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /app/bin/app

# Final stage - create minimal production image
FROM scratch

# Import certificates and timezone data from the build stage
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /usr/share/zoneinfo /usr/share/zoneinfo

# Set environment variables
ENV TZ=UTC
ENV GIN_MODE=release

# Copy the binary from the build stage
COPY --from=build /app/bin/app /app

# Command to run the application
ENTRYPOINT ["/app"]
