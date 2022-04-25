
PROJECT_NAME = $(shell basename "$(PWD)")
PROJECT_DIR=$(shell pwd)
META_PID = /tmp/.$(PROJECT_NAME)_meta.pid
DATA_PID = /tmp/.$(PROJECT_NAME)_data.pid
BASE_DIR := $(PROJECT_DIR)/build
VERSION = 0.1.2
DATETIME = `date +%FT%T%z`
SOURCES := $(PROJECT_DIR)/cmd


export GO111MODULE ?= on
export GOPROXY ?= https://goproxy.io,direct
export GOSUMDB ?= sum.golang.org
export GOARCH ?= amd64
OS := $(shell uname)
ifeq ($(OS), Linux)
	export GOOS ?= linux
else ifeq ($(OS), Darwin)
	export GOOS ?= darwin
else
	export GOOS ?= windows
endif
# executor filename
ifeq ($(GOOS), windows)
	export BIN_NAME ?= .exe
else
	export BIN_NAME ?=
endif

CGO ?= 0
ifeq ($(DEBUG), true)
	BUILD_TYPE := debug
	GCFLAGS := -gcflags="all=-N -l"
	LCFLAGS :=
else
	BUILD_TYPE := release
	LDFLAGS := "-s -w"
endif

OUT_DIR := $(BASE_DIR)/$(GOOS)_$(GOARCH)
BIN_DIR := $(BASE_DIR)/$(GOOS)_$(GOARCH)/bin
CONF_DIR := $(BASE_DIR)/$(GOOS)_$(GOARCH)/conf
LOG_DIR := $(BASE_DIR)/$(GOOS)_$(GOARCH)/logs

## help: Print this help for all options
.PHONY: help
help: $(realpath $(firstword $(MAKEFILE_LIST)))
	@echo
	@echo " Choose a command run in "$(PROJECT_NAME)":"
	@echo
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'
	@echo


## freets: A cli client to FreeTSDB.
.PHONY: freets
freets:
	$(info > "Buiding freets binaries ...")
	@CGO_ENABLED=$(CGO) GOOS=$(GOOS) GOARCH=$(GOARCH) go build $(GCFLAGS) -ldflags=$(LDFLAGS) -o $(BIN_DIR)/freets$(BIN_NAME) $(wildcard $(SOURCES)/freets/*.go)


## freets_inspect: Displays detailed information about FreeTSDB data files.
.PHONY: freets_inspect
freets_inspect:
	$(info > "Buiding freets_inspect binaries ...")
	@CGO_ENABLED=$(CGO) GOOS=$(GOOS) GOARCH=$(GOARCH) go build $(GCFLAGS) -ldflags=$(LDFLAGS) -o $(BIN_DIR)/freets_inspect$(BIN_NAME) $(wildcard $(SOURCES)/freets_inspect/*.go)


## freets_tools: Displays detailed information about FreeTSDB data files.
.PHONY: freets_tools
freets_tools:
	$(info > "Buiding freets_tools binaries ...")
	@CGO_ENABLED=$(CGO) GOOS=$(GOOS) GOARCH=$(GOARCH) go build $(GCFLAGS) -ldflags=$(LDFLAGS) -o $(BIN_DIR)/freets_tools$(BIN_NAME) $(wildcard $(SOURCES)/freets_tools/*.go)


## freets_tsm: Converts b1 or bz1 shards (from FreeTSDB releases earlier than v0.11) to the current tsm1 format.
.PHONY: freets_tsm
freets_tsm:
	$(info > "Buiding freets_tsm binaries ...")
	@CGO_ENABLED=$(CGO) GOOS=$(GOOS) GOARCH=$(GOARCH) go build $(GCFLAGS) -ldflags=$(LDFLAGS) -o $(BIN_DIR)/freets_tsm$(BIN_NAME) $(wildcard $(SOURCES)/freets_tsm/*.go)


## freetsd: The FreeTSDB server.
.PHONY: freetsd
freetsd:
	$(info > "Buiding freetsd binaries ...")
	@CGO_ENABLED=$(CGO) GOOS=$(GOOS) GOARCH=$(GOARCH) go build $(GCFLAGS) -ldflags=$(LDFLAGS) -o $(BIN_DIR)/freetsd$(BIN_NAME) $(wildcard $(SOURCES)/freetsd/*.go)


## freetsd_ctl: The FreeTSDB server manager tool.
.PHONY: freetsd_ctl
freetsd_ctl:
	$(info > "Buiding freetsd_ctl binaries ...")
	@CGO_ENABLED=$(CGO) GOOS=$(GOOS) GOARCH=$(GOARCH) go build $(GCFLAGS) -ldflags=$(LDFLAGS) -o $(BIN_DIR)/freetsd_ctl$(BIN_NAME) $(wildcard $(SOURCES)/freetsd_ctl/*.go)


## freetsd_meta: The FreeTSDB metanode server.
.PHONY: freetsd_meta
freetsd_meta:
	$(info > "Buiding freetsd_meta binaries ...")
	@CGO_ENABLED=$(CGO) GOOS=$(GOOS) GOARCH=$(GOARCH) go build $(GCFLAGS) -ldflags=$(LDFLAGS) -o $(BIN_DIR)/freetsd_meta$(BIN_NAME) $(wildcard $(SOURCES)/freetsd_meta/*.go)


## store: Store command displays detailed information about FreeTSDB data files.
.PHONY: store
store:
	$(info > "Buiding store binaries ...")
	@CGO_ENABLED=$(CGO) GOOS=$(GOOS) GOARCH=$(GOARCH) go build $(GCFLAGS) -ldflags=$(LDFLAGS) -o $(BIN_DIR)/store$(BIN_NAME) $(wildcard $(SOURCES)/store/*.go)


## build: Build application's binaries
.PHONY: build
build: freets freets_inspect freets_tools freets_tsm freetsd freetsd_ctl freetsd_meta store
	$(info > "Buiding application binary: $(OUT_DIR)/$(PROJECT_NAME)$(BIN_NAME)")
	@mkdir -p $(CONF_DIR)
	@mkdir -p $(LOG_DIR)
	@test -f $(PROJECT_DIR)/conf/freetsdb.conf && cp $(PROJECT_DIR)/conf/freetsdb.conf $(CONF_DIR)/freetsdb.conf
	@test -f $(PROJECT_DIR)/conf/freetsdb-meta.conf && cp $(PROJECT_DIR)/conf/freetsdb-meta.conf $(CONF_DIR)/freetsdb-meta.conf


## startMetaNode: start freetsdb meta-node
.PHONY: startMetaNode
startMetaNode:
	$(info > Starting meta-node, output is redirected to $(LOG_DIR)/freetsdb-meta.log)
	@nohup $(BIN_DIR)/freetsd_meta$(BIN_NAME) -config $(CONF_DIR)/freetsdb-meta.conf > $(LOG_DIR)/freetsdb-meta.log 2>&1 & echo $$! > $(META_PID)
	@cat $(META_PID) | sed "/^/s/^/  \>meta node pid: /"


## startDataNode: start freetsdb data-node
.PHONY: startDataNode
startDataNode:
	$(info > Stopping data-node, output is redirected to $(LOG_DIR)/freetsdb-data.log)
	@nohup $(BIN_DIR)/freetsd$(BIN_NAME) -config $(CONF_DIR)/freetsdb.conf > $(LOG_DIR)/freetsdb-data.log 2>&1 & echo $$! > $(DATA_PID)
	@cat $(DATA_PID) | sed "/^/s/^/  \>data node pid: /"


## stopMetaNode: Stop freetsdb meta-node
.PHONY: stopMetaNode
stopMetaNode:
	$(info > Stopping $(PROJECT_NAME) meta-node ...)
	@cat $(META_PID) | sed "/^/s/^/  \>  Killing PID: /"
	@-kill `cat $(META_PID)` 2>/dev/null || true
	@-rm -f $(META_PID)


## stopDataNode: Stop freetsdb data-node
.PHONY: stopDataNode
stopDataNode:
	$(info > Stopping $(PROJECT_NAME) data-node ...)
	@cat $(DATA_PID) | sed "/^/s/^/  \>  Killing PID: /"
	@-kill `cat $(DATA_PID)` 2>/dev/null || true
	@-rm -f $(DATA_PID)


## clean: Clean up the output and the binary of the application
.PHONY: clean
clean: stopDataNode stopMetaNode
	$(info > Cleanning up $(OUT_DIR))
	@-rm -rf $(OUT_DIR)
	@-cat $(DATA_PID) | awk '{print $1}' | xargs kill -9
	@-cat $(META_PID) | awk '{print $1}' | xargs kill -9
	@-rm -f $(DATA_PID) $(META_PID)

