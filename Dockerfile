ARG FROM_IMAGE

FROM ${FROM_IMAGE} AS builder

ARG OS_TARGET

WORKDIR /go/src/app

COPY . .

RUN make ${OS_TARGET}

FROM scratch

WORKDIR /

ARG APP_NAME

COPY --from=builder /go/src/app/$APP_NAME ./toTestAPP
COPY --from=alpine:latest /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
ENTRYPOINT ["./toTestAPP", "start"]