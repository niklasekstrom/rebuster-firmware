QUARTUS_ROOT ?= /opt/intelFPGA_lite/19.1/quartus
QUARTUS_BIN := $(QUARTUS_ROOT)/bin
QUARTUS_SH := $(QUARTUS_BIN)/quartus_sh
QUARTUS_MAP := $(QUARTUS_BIN)/quartus_map

PROJECT_DIR := hdl
PROJECT := ReBuster
REV ?= rev2
REVISIONS := rev1 rev2
ARCHIVE_DIR ?= bin
ARCHIVE_SEQ ?=
ARCHIVE_HASH ?= $(shell git rev-parse --short=6 HEAD)

.PHONY: all check check-all compile compile-all archive-pof clean help

define run_quartus
	cd $(PROJECT_DIR) && \
		qpf_backup=$$(mktemp $(PROJECT).qpf.XXXXXX) && \
		qsf_backup=$$(mktemp $(REV).qsf.XXXXXX) && \
		cp $(PROJECT).qpf $$qpf_backup && \
		cp $(REV).qsf $$qsf_backup && \
		trap 'mv "$$qpf_backup" $(PROJECT).qpf; mv "$$qsf_backup" $(REV).qsf' EXIT INT TERM HUP && \
		$(1)
endef

all: check

check:
	$(call run_quartus,$(QUARTUS_MAP) --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(REV))

check-all:
	@for rev in $(REVISIONS); do \
		$(MAKE) check REV=$$rev || exit $$?; \
	done

compile:
	$(call run_quartus,$(QUARTUS_SH) --flow compile $(PROJECT) -c $(REV))

compile-all:
	@for rev in $(REVISIONS); do \
		$(MAKE) compile REV=$$rev || exit $$?; \
	done

archive-pof:
ifndef ARCHIVE_SEQ
	$(error ARCHIVE_SEQ is required, e.g. make archive-pof ARCHIVE_SEQ=34)
endif
	@mkdir -p $(ARCHIVE_DIR)
	@seq='$(ARCHIVE_SEQ)'; \
		if [ $${#seq} -eq 1 ]; then seq=0$$seq; fi; \
		out='$(ARCHIVE_DIR)/$(REV)_'$$seq'_$(ARCHIVE_HASH).pof'; \
		cp '$(PROJECT_DIR)/output_files/$(REV).pof' "$$out"; \
		printf 'Wrote %s\n' "$$out"

clean:
	rm -rf $(PROJECT_DIR)/db $(PROJECT_DIR)/incremental_db $(PROJECT_DIR)/output_files
	rm -f $(PROJECT_DIR)/*.rpt $(PROJECT_DIR)/*.summary $(PROJECT_DIR)/*.smsg $(PROJECT_DIR)/*.qws

help:
	@printf 'Targets:\n'
	@printf '  make check          Run quartus_map analysis/synthesis for REV=%s\n' '$(REV)'
	@printf '  make check-all      Run quartus_map for rev1 and rev2\n'
	@printf '  make compile        Run full Quartus compile for REV=%s\n' '$(REV)'
	@printf '  make compile-all    Run full Quartus compile for rev1 and rev2\n'
	@printf '  make archive-pof    Copy REV POF to bin/REV_NN_HASH.pof\n'
	@printf '  make clean          Remove Quartus generated output\n'
	@printf '\nVariables:\n'
	@printf '  REV=rev1|rev2       Select project revision, default rev2\n'
	@printf '  ARCHIVE_SEQ=NN      Sequence number for archive-pof\n'
	@printf '  ARCHIVE_HASH=HASH   Hash field, default current short hash\n'
	@printf '  QUARTUS_ROOT=...    Select Quartus install root, default %s\n' '$(QUARTUS_ROOT)'
