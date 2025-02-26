ARG VPP_VERSION=v22.06-rc0-147-g1c5485ab8
FROM ghcr.io/edwarnicke/govpp/vpp:${VPP_VERSION} as go
COPY --from=golang:1.16.3-buster /usr/local/go/ /go
ENV PATH ${PATH}:/go/bin
ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOBIN=/bin
RUN rm -r /etc/vpp
RUN go get github.com/go-delve/delve/cmd/dlv@v1.6.0
RUN go get github.com/edwarnicke/dl
RUN dl \
    https://github.com/spiffe/spire/releases/download/v1.2.2/spire-1.2.2-linux-x86_64-glibc.tar.gz | \
    tar -xzvf - -C /bin --strip=2 spire-1.2.2/bin/spire-server spire-1.2.2/bin/spire-agent
RUN dl \
    https://github.com/coredns/coredns/releases/download/v1.9.1/coredns_1.9.1_linux_amd64.tgz | \
    tar -xzvf - -C /bin coredns

FROM go as build
WORKDIR /build
COPY go.mod go.sum ./
COPY ./local ./local
COPY ./internal/imports ./internal/imports
RUN go build ./internal/imports
COPY . .
RUN go build -o /bin/cmd-nse-simple-vl3-docker .

FROM build as test
CMD go test -test.v ./...

FROM test as debug
CMD dlv -l :40000 --headless=true --api-version=2 test -test.v ./...

FROM ghcr.io/edwarnicke/govpp/vpp:${VPP_VERSION} as runtime
COPY --from=build /bin/cmd-nse-simple-vl3-docker /bin/cmd-nse-simple-vl3-docker
COPY --from=build /bin/spire-server /bin/spire-server
COPY --from=build /bin/spire-agent /bin/spire-agent
COPY --from=build /bin/coredns /bin/coredns
ENTRYPOINT [ "/bin/cmd-nse-simple-vl3-docker" ]
