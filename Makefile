GO ?= go
BIN ?= sing-box
PKG ?= ./cmd/sing-box

.PHONY: build build-linux build-darwin clean

build:
	$(GO) build -trimpath -o ./bin/$(BIN) $(PKG)

build-linux:
	GOOS=linux GOARCH=amd64 $(GO) build -trimpath -o ./bin/$(BIN)-linux-amd64 $(PKG)

build-darwin:
	GOOS=darwin GOARCH=arm64 $(GO) build -trimpath -o ./bin/$(BIN)-darwin-arm64 $(PKG)

clean:
	rm -rf ./bin
