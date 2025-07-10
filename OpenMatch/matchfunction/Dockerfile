FROM golang:1.24-alpine AS builder

WORKDIR /app/

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Go 빌드
RUN GOOS=linux \
    GOARCH=amd64 \
    CGO_ENABLED=0 \
    go build -v \
    -ldflags="-s -w" \
    -o /app/run \
    .

ENTRYPOINT ["/app/run"]
