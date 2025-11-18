FROM golang:1.25.4-alpine3.22 AS builder

WORKDIR /app

COPY /go.mod .

RUN go mod download
RUN go mod verify

COPY . .

RUN go build -o main .

FROM alpine:3.22

RUN apk add --no-cache curl

COPY --from=builder /app/main .

RUN adduser \
  --disabled-password \
  --gecos "" \
  --home "/nonexistent" \
  --shell "/sbin/nologin" \
  --no-create-home \
  --uid 65532 \
  user

USER user:user

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/healthz || exit 1

EXPOSE 3000

CMD ["./main"]