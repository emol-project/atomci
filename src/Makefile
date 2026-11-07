#!/bin/make 
# new makefile
####################################
#f7=g77 -O2 -c -fno-automatic -Wno-globals -fno-globals
#lf7=g77
#f7=xlf -O  -c
#lf7=xlf -O

# -fallow-argument-mismatch: on gfortran 10+ an argument type/rank mismatch is a
# HARD ERROR by default (the flag's meaning flipped at gcc 10).  All real
# mismatches have been fixed at the source; a full-tree audit (2026-08-11,
# compile every src/*.f without this flag and triage every hit)
# found exactly 15 diagnostics across 3
# files, all deliberate:
#   - cici.f's two EMDEL by-design puns (12 diagnostics) -- it ERSTOPs before
#     dereferencing anything, an unimplemented-path abort stub.
#   - mcfock.f/mcdriv.f's OE/K2/CIV (3 diagnostics) -- each a %R8-typed,
#     WKCORE-allocated slice of the untyped /work/ VAR() heap, deliberately
#     reinterpreted as REAL*8 (the established WKCORE/"Bucket-1" convention).
# mcscf2.f's incomplete "remove projection operator" edit (P implicitly
# REAL(4) against a REAL(8) actual) was a FOURTH, accidental instance -- not
# a deliberate pattern -- and was fixed at the source instead of relying on
# this flag, which is why it is not in the count above.
# NOTE ON COMPLETENESS: this audit is bounded by what gfortran's own
# same-COMPILATION argument-consistency check can see -- corrected from an
# earlier "same-file" phrasing here: it only compares multiple
# calls to the SAME routine visible within one compile invocation, which
# happened to mean "one file" for this audit's file-by-file methodology,
# but is not the same bound in general -- a later, cross-file audit found 3
# of these very
# 15 diagnostics (mcfock.f/mcdriv.f's XMOVE hits) were flagged even though
# XMOVE's real definition (mcvut.f) was never part of that compile at all.
# So: a routine called once per compilation, or called inconsistently only
# across separately-compiled files, is structurally invisible to it (this
# is why one such bug -- MJCDG's kind mismatch -- needed a different,
# purpose-built, cross-file static-analysis tool to find at all). "15, all
# triaged" is
# complete for what this method can see, not a proof nothing else is
# masked.  This flag is codegen-neutral (only downgrades the diagnostic),
# so objects match a build without it.
# The flag only EXISTS from gfortran 10 on (8/9 reject it as unknown, and don't
# need it -- there the mismatch is a warning), so add it only when major >= 10.
GFORTRAN_MAJOR := $(shell gfortran -dumpversion 2>/dev/null | cut -d. -f1)
ALLOW_MISMATCH := $(shell test "$(GFORTRAN_MAJOR)" -ge 10 2>/dev/null && echo -fallow-argument-mismatch)
# wt9x.f optimisation level: gcc-8 (major < 9) miscompiles FUNCTION WT9X via its
# -ftree-dominator-opts pass, so force -O0 there ONLY; gcc-9+ are correct at -O2
# (and -O0 there would cost ~1.5-12% for no benefit).  Same GFORTRAN_MAJOR gate as
# ALLOW_MISMATCH; defaults to -O2 when the version can't be determined.  See the
# wt9x.o rule below and the gf8-wt9x-rootcause investigation.
# Both this gate and ALLOW_MISMATCH's use `test -N -lt/-ge M`, a NUMERIC
# comparison -- immune to the "16 sorts before 9" trap a naive string/lexical
# compare of GFORTRAN_MAJOR would fall into. Confirmed directly, not just by
# the numeric-test argument: verified on GCC 16.1.0 (macOS/Homebrew) that both
# branches evaluate correctly at a two-digit major -- forcing the wt9x.o
# recipe by hand there produced `-O2` (not `-O0`) and `-fallow-argument-
# mismatch` was present, exactly as intended. Previously only exercised
# against single-digit and low-double-digit majors (8-15, Debian).
# KEEP THIS GATE even though gcc-8 is no longer a supported build target
# (its container image's package repositories
# are archived, so it can't even be point-verified anymore). It is retained
# deliberately for a compiler version below the current floor -- a
# silent-wrong-answer trap costs one comparison to keep; do not delete it as
# dead code just because gcc-8 itself dropped out of the supported range.
WT9X_OPT := $(shell test "$(GFORTRAN_MAJOR)" -lt 9 2>/dev/null && echo -O0 || echo -O2)
# -fno-automatic: gives every routine's ordinary (non-SAVEd, non-COMMON)
# locals static storage duration instead of stack storage. This is more than
# a performance/legacy-compatibility default -- two independent, confirmed
# reliances on it:
#   - ATDRV's local MCONF is reliably zero (not stack garbage)
#     because of this flag -- part of why that defect's corruption was
#     benign in practice rather than randomly crashing.
#   - native multi-pass decks (samples/native/f.stdin's three &CNTL
#     groups) restate most of &TR's and all of &CI's/&RS's parameters on
#     every pass; that restatement is largely redundant only because this
#     flag makes those routines' locals persist across calls -- none of
#     them are SAVEd or in COMMON. Dropping this flag would not error; it
#     would silently start reading indeterminate stack values for any
#     repeated-but-omitted parameter on a pass after the first.
# Do not remove or make this conditional without understanding both reliances above first.
f7=gfortran -O2 -c -fno-automatic -ffixed-form $(ALLOW_MISMATCH)
lf7=gfortran
# Invoke the freshly built in-tree tools by absolute path so no build rule
# depends on the current directory being on PATH.  CURDIR is make's own working
# directory (the top-level build dir where fpl/tfpl/cfpa/cfpb are built) and is
# stable even when a recipe subshell cd's into gDKsapporo/.
fpl=$(CURDIR)/fpl

L=fpl90lib.o iqtime.o clockm.o
OT=iqtime.o clockm.o
OTMP=tfpl90lib.o iqtime.o
 SO=./
 INC=include/
 GDKS=gDKsapporo/
#L=fpl90lib.o fplnews.o

# --- BLAS/LAPACK -------------------------------------------------------
# System BLAS/LAPACK only (the bundled src/lapack/ copy was removed --
# swapping the in-tree DSYGV for the system one was verified to reproduce
# identical results, so this is known-safe). Detected via pkg-config
# (lapack+blas, then openblas). There is no bundled fallback left, so a
# missing system LAPACK must fail loudly and early -- see lapack-guard
# below -- rather than at link time with an undefined `dsygv_`/etc. symbol.

# pkg-config search-path augmentation (macOS / Homebrew).  Homebrew keeps its
# openblas/lapack formulae keg-only, so their pkgconfig dirs are NOT on
# pkg-config's default search path -- `pkg-config --exists lapack blas` then
# fails even though the libraries are installed.  When `brew` is present, add
# openblas' and lapack's pkgconfig dirs (discovered via `brew --prefix`, which
# resolves correctly on BOTH Intel /usr/local and Apple Silicon /opt/homebrew)
# to PKG_CONFIG_PATH, and export it so both the detection below and the
# LAPACK_LINK `pkg-config --libs` call see it.  No-op on Linux (no brew), so the
# existing pkg-config search path -- and thus the Debian behaviour -- is
# unchanged.
PKG_CONFIG_PATH := $(shell p="$$PKG_CONFIG_PATH"; \
	if command -v brew >/dev/null 2>&1; then \
		for f in openblas lapack; do \
			d="$$(brew --prefix $$f 2>/dev/null)/lib/pkgconfig"; \
			[ -d "$$d" ] && p="$$d:$$p"; \
		done; \
	fi; \
	printf '%s' "$$p")
# Also exported (not just assigned above) for gDKsapporo/Makefile's own
# `pkg-config` lookup: `$(LIBgDKsapporo)`'s recipe below runs `make` as a
# child process in gDKsapporo/, and a child process picks up this variable
# from its inherited environment -- ordinary process inheritance, unaffected
# by the $(shell)-at-parse-time defect described below, since it is already
# part of gDKsapporo's make's environment before that make even starts.
export PKG_CONFIG_PATH

# NOTE: PKG_CONFIG_PATH is passed to `pkg-config` explicitly below, as a
# literal environment assignment on the command $(shell) runs, rather than
# relying on the `export` above to reach it. Apple's own /usr/bin/make on
# macOS is GNU Make 3.81 (from 2006, and not updated by Apple) -- and 3.81
# does not put a variable this SAME makefile exports mid-parse into the
# environment of a $(shell ...) call later in that same parse pass. Measured
# directly: `export FOO` followed by `$(shell echo $$FOO)` in a three-line
# makefile yields empty on 3.81. Every other
# make in use here (GNU Make 4.x on Debian, and Homebrew's own `make`
# package) does not have this defect, but the explicit form costs nothing
# there either. Do NOT "simplify" this back to a bare
# `pkg-config --libs ...` that relies on the export two lines up -- that is
# exactly the form that silently produced an empty LAPACK_LINK on every
# macOS machine using Apple's stock make, even with LAPACK correctly
# installed and correctly discovered above.
LAPACK_LINK := $(shell PKG_CONFIG_PATH="$(PKG_CONFIG_PATH)" pkg-config --libs lapack blas 2>/dev/null || PKG_CONFIG_PATH="$(PKG_CONFIG_PATH)" pkg-config --libs openblas 2>/dev/null)

# --- fail loudly if system BLAS/LAPACK is missing, before any link is attempted ---
.PHONY: lapack-guard
lapack-guard:
	@if [ -z "$(strip $(LAPACK_LINK))" ]; then \
		echo "System BLAS/LAPACK not found (pkg-config lapack+blas, then openblas)." >&2; \
		echo "Install it, then re-run make:" >&2; \
		echo "  Debian/Ubuntu : sudo apt-get install liblapack-dev libblas-dev   (or libopenblas-dev)" >&2; \
		echo "  Fedora/RHEL   : sudo dnf install lapack-devel blas-devel          (or openblas-devel)" >&2; \
		echo "  macOS (brew)  : brew install openblas lapack" >&2; \
		echo "" >&2; \
		echo "Installed but NOT detected?  Its .pc files may be off pkg-config's search" >&2; \
		echo "path (common with Homebrew's keg-only openblas/lapack).  Point pkg-config" >&2; \
		echo "at them and re-run, e.g.:" >&2; \
		echo "  export PKG_CONFIG_PATH=\"\$$(brew --prefix openblas)/lib/pkgconfig:\$$(brew --prefix lapack)/lib/pkgconfig:\$$PKG_CONFIG_PATH\"" >&2; \
		echo "  make" >&2; \
		exit 1; \
	fi

LIBgDKsapporo = gDKsapporo/libgDKsapporo.a
####################################
default: all

.SUFFIXES:
.SUFFIXES: .o .f .fpl .c


.f.o:;  $(f7) $<
.fpl.f: ;  $(fpl) < $<
.fpl.o: ; ( $(fpl) < $< ;$(f7) $*.f )

# --- edit-target guard (generated-.f-edit hazard) ---
# Every X.f here is FPL-generated from X.fpl and gitignored
# -- so a stray edit to X.f instead of X.fpl leaves no `git status` signal and
# is silently regenerated away the next time X.fpl (or fpl itself) changes.
# mtime alone can't tell a fresh regeneration from a same-since hand edit to
# X.f (both leave X.f newer than X.fpl -- true after every ordinary build, not
# just a mistake), so this can only ever be a blunt, always-on reminder, not a
# precise detector; deliberately one aggregate line, not one per file, so it
# doesn't train the reader to tune it out.
.PHONY: fpl-guard
fpl-guard:
	@n=0; \
	for fpl in $(SO)*.fpl; do \
		b=$${fpl%.fpl}; \
		[ -f "$$b.f" ] && [ "$$b.f" -nt "$$fpl" ] && n=$$((n+1)); \
	done; \
	[ $$n -gt 0 ] && echo "note: $$n FPL-generated .f file(s) are newer than their .fpl (normal after a build). These files are gitignored: a direct edit to one leaves no git-status signal and is silently discarded on the next regeneration. If you meant to change behavior, edit the matching .fpl instead." || true

# --- gcc-8 wt9x.f miscompilation workaround (version-gated via $(WT9X_OPT)) ---
# gcc-8's dominator-opts (DOM) jump-threading pass miscompiles FUNCTION WT9X in
# wt9x.f at -O1/-O2/-O3, producing wrong Wigner-9j coefficients and a wrong CI
# energy (boron: -28.57 instead of the correct -24.6462).  -O0 is correct.
# gcc-9..15 compile it correctly at every -O level, so WT9X_OPT selects -O0 only
# for gcc-8 and -O2 (normal) for gcc-9+.  Mirrors the .fpl.o rule above (regen
# wt9x.f from wt9x.fpl) but with the gated optimisation level.
wt9x.o: wt9x.fpl
	$(fpl) < wt9x.fpl
	gfortran $(WT9X_OPT) -c -fno-automatic -ffixed-form $(ALLOW_MISMATCH) wt9x.f

# make file for atomci
OMC= mcdriv.o mcci.o mcjsks.o mcfock.o mcscf0.o mcscf1.o mcscf2.o mcscf3.o mcscf4.o mcadrs.o mcsut.o mcvut.o mchtr.o jacjac.o mcxut.o mcmain.o mcmcsf.o h1non.o prttcp.o
OB=cfpset.o ciai.o cici.o ciex.o cinewx.o cipt.o cirs.o citr.o ciutil.o ciwf.o fdopen.o diagk.o wkcore.o ciptrs.o setcfp.o setwig.o smat.o fgf3.o aiigtf.o aiigt4.o norm.o  mynewf.o extap1.o aiigr4.o
OA=trnsfm.o trnona.o ntrnpp.o wfetap.o extape.o exij.o xcfp.o delta.o convt.o shmsd.o fishl.o cfac.o fiang.o isp.o f3l.o shms.o afact.o dspcfp.o xwig6j.o wfgens.o aiistf.o shmsrc.o ntisqt.o setiad.o ior.o mjcdg.o wt9x.o setcom.o readia.o dcoda.o ctoi4.o ctoi4n.o ctor8.o mcp.o aiimcp.o bit.o

OCFPB= fdopen.o dspcfp.o dcoda.o ctoi4n.o

OGDK= $(GDKS)chdns.o $(GDKS)clear.o $(GDKS)dbsval.o $(GDKS)dgamm.o $(GDKS)dicgam.o $(GDKS)erf.o $(GDKS)fbsval.o $(GDKS)fncset.o $(GDKS)gdk.o $(GDKS)glset.o $(GDKS)h1rel2.o $(GDKS)init.o $(GDKS)initdk.o $(GDKS)oei.o $(GDKS)trfm1.o $(GDKS)trfm2.o $(GDKS)trmt.o


E=$(INC)ERMSG $(INC)PARAM
INCMAIN=$(INC)INCWORK $(INC)INCMACRO $(INC)INCMAIN $(INC)INCWKEXC $(INC)INCDATA 
INCALL=$(INC)UPDATE $(INC)CPYRIGHT 

FPLSRC = $(SO)*.fpl
$(FPLSRC): $(INCMAIN) $(INCALL) $(INC)CIERINF $(INC)COMDIAG $(INC)DATALTRI  $E
# Every .fpl file except fpl90.fpl needs the self-hosted `fpl` binary built
# first -- the .fpl.f/.fpl.o suffix rules (and wt9x.o's own rule) invoke
# $(fpl) in their RECIPE but never declared it as a prerequisite, so a
# parallel build (`make -j`) can race a downstream .fpl compile against
# fpl's own build (observed: `ci.fpl` losing the race to `fpl` under
# `make -j4` from clean). fpl90.fpl is the one exception -- it bootstraps
# via `tfpl`, not `fpl` (see the fpl90.f/fpl90lib.f/fplnews.f rule below);
# adding `fpl` as ITS prerequisite too would be circular. (filter-out must
# match $(SO)fpl90.fpl, i.e. "./fpl90.fpl" -- $(wildcard $(SO)*.fpl) expands
# with that "./" prefix; filtering the bare "fpl90.fpl" silently fails to
# exclude it and re-creates the cycle, which make then breaks unpredictably
# with a "Circular ... dependency dropped" warning instead of erroring.)
$(filter-out $(SO)fpl90.fpl,$(wildcard $(SO)*.fpl)): fpl
OATGEN=atgen.o atlib.o fdopen.o


#all: lapack gDKsapporo fpl atomci atgen CFPTBL
#all: atomci tfpl

all: lapack-guard fpl-guard $(LIBgDKsapporo) fpl atomci atgen CFPTBL

clean:
	-rm CFPTBL cfpa cfpb fpl tfpl atgen atomci
	-rm *.o
	( cd gDKsapporo ; make clean )
	touch *.f *.fpl

####
atomci: lapack-guard $(LIBgDKsapporo) fpl ci.o $(OB)  $(OMC) $(OA)
	$(lf7) -o atomci ci.o $(OB) $L $(OMC) $(OA) $(LIBgDKsapporo) $(LAPACK_LINK)

####
# Only the archive atomci needs is built here; the gDKsapporo "all" target
# also links its own dkint test exe against system LAPACK (src/gDKsapporo/
# Makefile), which is a separate maintenance tool, not part of this build.
$(LIBgDKsapporo): lapack-guard
	( cd gDKsapporo ; make libgDKsapporo.a )

####
# atgen.f is FPL-generated from atgen.fpl, same relationship as
# fpl90.f/fpl90lib.f/fplnews.f/wt9x.f below -- but GNU Make's suffix-rule
# resolution (.SUFFIXES above lists .f before .fpl) prefers the plain
# .f.o: rule over .fpl.o: whenever atgen.f already exists, regardless of
# atgen.fpl's own timestamp -- so without this explicit rule, `fpl <
# atgen.fpl` is never invoked by a normal build no matter how atgen.fpl
# changes. This rule gives atgen.f a
# real target with its own prerequisites, which Make evaluates before
# ever reaching the suffix rules, mirroring fpl90.f's rule below.
atgen.f: atgen.fpl fpl
	$(fpl) < atgen.fpl

####
# The same class of Make suffix-rule gotcha, audited by class: every one of these .f files is FPL-generated
# from the matching .fpl, was tracked in git at the time (they are
# gitignored now; the rules below still matter for a stale local .f),
# and had no explicit rule -- so
# on a fresh checkout (.fpl and .f share the same checkout mtime, a tie,
# which Make does not treat as "prerequisite newer than target") the
# generic .fpl.f: suffix rule never fires and a normal build silently
# keeps whatever .f happens to be committed, no matter how the .fpl
# changes. Confirmed empirically (tied-mtime clean-clone build leaves
# these .f files byte-identical to their committed content; a real edit,
# whose mtime is unambiguously newer, does trigger regeneration -- so
# this was invisible during ordinary same-session development and only
# bites a fresh clone or CI checkout). Same fix as atgen.f above, applied
# to every remaining case at once: an explicit target with `fpl` (the
# freshly-built preprocessor, always newer than a checkout-tied .fpl) as
# a prerequisite, so Make evaluates this rule before ever reaching the
# suffix rules, regardless of the .fpl/.f timestamp relationship.
cfpset.f: cfpset.fpl fpl
	$(fpl) < cfpset.fpl
ciai.f: ciai.fpl fpl
	$(fpl) < ciai.fpl
cici.f: cici.fpl fpl
	$(fpl) < cici.fpl
ciex.f: ciex.fpl fpl
	$(fpl) < ciex.fpl
ci.f: ci.fpl fpl
	$(fpl) < ci.fpl
cipt.f: cipt.fpl fpl
	$(fpl) < cipt.fpl
ciptrs.f: ciptrs.fpl fpl
	$(fpl) < ciptrs.fpl
cirs.f: cirs.fpl fpl
	$(fpl) < cirs.fpl
citr.f: citr.fpl fpl
	$(fpl) < citr.fpl
ciutil.f: ciutil.fpl fpl
	$(fpl) < ciutil.fpl
ciwf.f: ciwf.fpl fpl
	$(fpl) < ciwf.fpl
dcoda.f: dcoda.fpl fpl
	$(fpl) < dcoda.fpl
extap1.f: extap1.fpl fpl
	$(fpl) < extap1.fpl
extape.f: extape.fpl fpl
	$(fpl) < extape.fpl
fdopen.f: fdopen.fpl fpl
	$(fpl) < fdopen.fpl
jacjac.f: jacjac.fpl fpl
	$(fpl) < jacjac.fpl
mcadrs.f: mcadrs.fpl fpl
	$(fpl) < mcadrs.fpl
mcci.f: mcci.fpl fpl
	$(fpl) < mcci.fpl
mcdriv.f: mcdriv.fpl fpl
	$(fpl) < mcdriv.fpl
mcfock.f: mcfock.fpl fpl
	$(fpl) < mcfock.fpl
mchtr.f: mchtr.fpl fpl
	$(fpl) < mchtr.fpl
mcjsks.f: mcjsks.fpl fpl
	$(fpl) < mcjsks.fpl
mcmain.f: mcmain.fpl fpl
	$(fpl) < mcmain.fpl
mcmcsf.f: mcmcsf.fpl fpl
	$(fpl) < mcmcsf.fpl
mcscf0.f: mcscf0.fpl fpl
	$(fpl) < mcscf0.fpl
mcscf1.f: mcscf1.fpl fpl
	$(fpl) < mcscf1.fpl
mcscf2.f: mcscf2.fpl fpl
	$(fpl) < mcscf2.fpl
mcscf3.f: mcscf3.fpl fpl
	$(fpl) < mcscf3.fpl
mcscf4.f: mcscf4.fpl fpl
	$(fpl) < mcscf4.fpl
mcsut.f: mcsut.fpl fpl
	$(fpl) < mcsut.fpl
mcvut.f: mcvut.fpl fpl
	$(fpl) < mcvut.fpl
ntisqt.f: ntisqt.fpl fpl
	$(fpl) < ntisqt.fpl
readia.f: readia.fpl fpl
	$(fpl) < readia.fpl
setcfp.f: setcfp.fpl fpl
	$(fpl) < setcfp.fpl
setcom.f: setcom.fpl fpl
	$(fpl) < setcom.fpl
setwig.f: setwig.fpl fpl
	$(fpl) < setwig.fpl
shmsrc.f: shmsrc.fpl fpl
	$(fpl) < shmsrc.fpl
wfetap.f: wfetap.fpl fpl
	$(fpl) < wfetap.fpl
wfgens.f: wfgens.fpl fpl
	$(fpl) < wfgens.fpl
wkcore.f: wkcore.fpl fpl
	$(fpl) < wkcore.fpl

atgen:  fpl $(OATGEN)  $L
	$(lf7) -o atgen  $(OATGEN) $L

####
fpl:  fpl90.o $L tfpl
	$(lf7) -o fpl fpl90.o $L
tfpl:  tfpl90.o $(OTMP)
	$(lf7) -o tfpl tfpl90.o $(OTMP)
fpl90.f fpl90lib.f fplnews.f: fpl90.fpl tfpl
	$(CURDIR)/tfpl < fpl90.fpl
tfpl90.o: tfpl90.f
	$(f7) tfpl90.f
iqtime.o: iqtime.c
	gcc -c iqtime.c

####
CFPTBL: cfpb
	$(CURDIR)/cfpb
cfpb: cfpb.o CFPDATA $(OCFPB) $(L)
	$(lf7) -o cfpb cfpb.o $(OCFPB) $(L) 
CFPDATA: cfpa
	$(CURDIR)/cfpa
cfpa: cfpa_1.o cfpa_2.o $(OT)
	$(lf7) -o cfpa cfpa_1.o cfpa_2.o $(OT) 
#	$(lf7) -o cfpa cfpa.o $(OT) 
