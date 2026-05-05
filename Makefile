QUARTUS_ROOT ?= /opt/intelFPGA_lite/19.1/quartus
QUARTUS_BIN := $(QUARTUS_ROOT)/bin
QUARTUS_SH := $(QUARTUS_BIN)/quartus_sh
QUARTUS_MAP := $(QUARTUS_BIN)/quartus_map

PROJECT_DIR := hdl
PROJECT := ReBuster
REV ?= rev2
REVISIONS := rev1 rev2

.PHONY: all check check-all compile compile-all clean help

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

clean:
	rm -rf $(PROJECT_DIR)/db $(PROJECT_DIR)/incremental_db $(PROJECT_DIR)/output_files
	rm -f $(PROJECT_DIR)/*.rpt $(PROJECT_DIR)/*.summary $(PROJECT_DIR)/*.smsg $(PROJECT_DIR)/*.qws

help:
	@printf 'Targets:\n'
	@printf '  make check          Run quartus_map analysis/synthesis for REV=%s\n' '$(REV)'
	@printf '  make check-all      Run quartus_map for rev1 and rev2\n'
	@printf '  make compile        Run full Quartus compile for REV=%s\n' '$(REV)'
	@printf '  make compile-all    Run full Quartus compile for rev1 and rev2\n'
	@printf '  make clean          Remove Quartus generated output\n'
	@printf '\nVariables:\n'
	@printf '  REV=rev1|rev2       Select project revision, default rev2\n'
	@printf '  QUARTUS_ROOT=...    Select Quartus install root, default %s\n' '$(QUARTUS_ROOT)'
