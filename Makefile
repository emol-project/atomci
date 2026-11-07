# Top-level delegator for ATOMCI.
#
# The build itself lives in src/ (all *.f/*.fpl/iqtime.c, include/, fplincl/,
# gDKsapporo/, and the real Makefile).  The atinputs front end
# (Python package + its bin/atinpgen wrapper) is in the top-level scripts/
# directory. The older Java generator (M. Sekiya's msekiya.jar) is kept in
# attic/msekiya-jar/ as an archive only: it is not built or installed, and
# its CERN Colt dependency is not distributed (docs/ATINPUTS_MANUAL.md).
#
#   make            build everything under src/ (atomci, atgen, fpl, CFPTBL,
#                   ...); artifacts stay in src/ where the build rules put them.
#   make install    assemble a clean, runnable layout under $(prefix)
#                   (default ./local):
#                       $(prefix)/bin/   atomci, atgen, fpl, atinpgen
#                                        (+ the atomci.sh helper)
#                       $(prefix)/lib/   atinputs/ (the Python package
#                                        bin/atinpgen runs)
#                       $(prefix)/CFPTBL
#                   CFPTBL sits at the $(prefix) ROOT (not under bin/ or a
#                   data/ dir) so it is easy to symlink into a work directory.
#                   Set ATOMCI_HOME=$(prefix), then for each calculation work in
#                   your own directory, symlink CFPTBL in, and run by path:
#                       export ATOMCI_HOME=$(prefix)
#                       mkdir run && cd run
#                       ln -sf "$$ATOMCI_HOME/CFPTBL" ./CFPTBL
#                       "$$ATOMCI_HOME/bin/atomci" < /path/to/samples/native/boron.stdin
#                   `make install` prints the exact export line to use.
#   make clean      clean src/ build artifacts, and remove the default ./local
#
# Requires system BLAS/LAPACK; src/
# Makefile's lapack-guard target fails with install instructions if it's
# missing, before any link is attempted.

prefix = $(CURDIR)/local

.PHONY: all clean install

all:
	$(MAKE) -C src all

clean:
	$(MAKE) -C src clean
	-rm -rf $(CURDIR)/local

install: all
	# $(prefix)/bin and $(prefix)/lib are fully owned by this install step --
	# wipe and recreate them fresh every time, rather than only ever adding
	# to them, so a tool that gets renamed or removed from the source tree
	# doesn't leave an old copy sitting on PATH forever. $(prefix)/CFPTBL is
	# a single file, always overwritten unconditionally below, so it
	# doesn't need this treatment.
	rm -rf $(prefix)/bin $(prefix)/lib
	mkdir -p $(prefix)/bin $(prefix)/lib
	cp src/atomci src/atgen src/fpl $(prefix)/bin
	cp scripts/atomci.sh $(prefix)/bin
	cp scripts/atinpgen.sh $(prefix)/bin/atinpgen
	chmod +x $(prefix)/bin/atinpgen
	rm -rf $(prefix)/lib/atinputs
	cp -r scripts/atinputs $(prefix)/lib/atinputs
	rm -rf $(prefix)/lib/atinputs/tests $(prefix)/lib/atinputs/__pycache__ \
	       $(prefix)/lib/atinputs/.pytest_cache $(prefix)/lib/atinputs/.hypothesis \
	       $(prefix)/lib/atinputs/csfgen/__pycache__
	rm -f $(prefix)/lib/atinputs/requirements-test.txt
	cp src/CFPTBL $(prefix)/CFPTBL
	@echo ""
	@echo "Installed to $(prefix)"
	@echo "Add this to your shell (or your shell profile):"
	@echo "  export ATOMCI_HOME=$(prefix)"
