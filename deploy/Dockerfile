FROM golang:1.17.2-alpine3.13 as builder

RUN go env -w GO111MODULE=on

# For china proxy
RUN go env -w GOPROXY=https://goproxy.cn,direct

WORKDIR /build

COPY . .

RUN CGO_ENABLED=0 GOARCH=amd64 GOOS=linux go build -mod vendor -v -o service /build/cmd/api/main.go

# FROM scratch
FROM alpine:3.17

WORKDIR /app

# add timezone
COPY --from=builder /usr/local/go/lib/time/zoneinfo.zip /zoneinfo.zip
ENV ZONEINFO /zoneinfo.zip

COPY --from=builder /build/config /app/config
COPY --from=builder /build/service /app/service
COPY --from=builder /build/migrations /app/migrations

CMD ["./service"]
