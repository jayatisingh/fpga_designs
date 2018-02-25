# Build and install our own Verilator, to work around versionining issues.
VERILATOR_VERSION=3.904
VERILATOR_SRCDIR ?= verilator/src/verilator-$(VERILATOR_VERSION)
VERILATOR_TARGET := $(abspath verilator/install/bin/verilator)
INSTALLED_VERILATOR ?= $(VERILATOR_TARGET)
$(VERILATOR_TARGET): $(VERILATOR_SRCDIR)/bin/verilator
	$(MAKE) -C $(VERILATOR_SRCDIR) installbin installdata
	touch $@

$(VERILATOR_SRCDIR)/bin/verilator: $(VERILATOR_SRCDIR)/Makefile
	$(MAKE) -C $(VERILATOR_SRCDIR) verilator_bin
	touch $@

$(VERILATOR_SRCDIR)/Makefile: $(VERILATOR_SRCDIR)/configure
	mkdir -p $(dir $@)
	cd $(dir $@) && ./configure --prefix=$(abspath verilator/install)

$(VERILATOR_SRCDIR)/configure: verilator/verilator-$(VERILATOR_VERSION).tar.gz
	rm -rf $(dir $@)
	mkdir -p $(dir $@)
	cat $^ | tar -xz --strip-components=1 -C $(dir $@)
	touch $@

verilator/verilator-$(VERILATOR_VERSION).tar.gz:
	mkdir -p $(dir $@)
	wget http://www.veripool.org/ftp/verilator-$(VERILATOR_VERSION).tgz -O $@

verilator: $(INSTALLED_VERILATOR)

# Run Verilator to produce a fast binary to emulate this circuit.
VERILATOR := $(INSTALLED_VERILATOR) --cc --exe
VERILATOR_FLAGS := --top-module $(MODEL) \
  +define+PRINTF_COND=\$$c\(\"verbose\",\"\&\&\"\,\"done_reset\"\) \
  +define+RANDOMIZE_GARBAGE_ASSIGN \
  +define+STOP_COND=\$$c\(\"done_reset\"\) --assert \
  --output-split 20000 \
  --output-split-cfuncs 20000 \
	-Wno-STMTDLY --x-assign unique \
  -I$(base_dir)/vsrc \
  -O3 -CFLAGS "$(CXXFLAGS) -DVERILATOR -DTEST_HARNESS=V$(MODEL) -include $(base_dir)/csrc/verilator.h"
cppfiles = $(addprefix $(base_dir)/csrc/, $(addsuffix .cc, $(CXXSRCS)))
headers = $(wildcard $(base_dir)/csrc/*.h)
