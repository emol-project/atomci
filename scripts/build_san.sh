#!/bin/bash
# Build a sanitizer variant of the full atomci binary (+ atgen's objects),
# out-of-tree so it never touches src/'s normal .o files.
#
# Usage: scripts/build_san.sh [variant]
#   san0 (default) -- THE validated recipe: -fcheck=all -fbounds-check
#                      -fsanitize=address,undefined, NO -finit-* poisoning.
#                      This is "the flag set that actually worked" for every
#                      finding above -- no -finit-* so a firing is a GENUINE
#                      memory/UB error, not a static-zero-init false positive
#                      (the code legitimately relies on BSS zero-init in
#                      places). Use this unless you have a specific reason
#                      to reach for one of the others below.
#   san1 -- ASan+UBSan only, no -fcheck/-fbounds-check. -fcheck=bounds false-
#           positives fatally on legacy result-neutral OOB reads (non-short-
#           circuit .AND. guards, A(1) dummies) and blocks reaching the CI
#           diagonalization; this is the variant that reaches the numerical
#           core when san0 can't get that far.
#   san  -- san0 + -finit-real=snan -finit-integer=-2147483648
#           -finit-logical=true. Poisons uninitialized memory so a READ of
#           it is caught even where it happens not to corrupt anything
#           downstream. Useful for the widest sweep; expect known-safe
#           BSS-zero-init reliance to also fire here (not necessarily a new
#           bug -- cross-check against san0).
#   val  -- no -finit-*, no -fsanitize (incompatible with valgrind's own
#           shadow tracking, which needs genuinely-uninitialized memory and
#           a plain, uninstrumented binary). Build this variant, then run
#           the result under valgrind yourself.
#
# Output: build_san_<variant>/atomci and /atgen (+ compile.log, and
# atomci.sha256/atgen.sha256 -- sha256sum manifests of the exact sources
# each binary was built from, checked by scripts/atinputs/tests/ at test
# time so a binary that has drifted from the working tree fails loudly
# instead of silently passing stale -- in the same dir).
# Prints the gfortran version used -- findings may be build-dependent (the
# gcc-8 wt9x miscompilation is the precedent for why that matters here).
set -u
cd "$(dirname "$0")/../src"
VARIANT="${1:-san0}"
OUTDIR="../build_san_$VARIANT"
mkdir -p "$OUTDIR"

GFORTRAN_VERSION="$(gfortran --version | head -1)"
GFORTRAN_MAJOR="$(gfortran -dumpversion 2>/dev/null | cut -d. -f1)"
# Same version gate as src/Makefile's ALLOW_MISMATCH: the flag only exists
# from gfortran 10 on (8/9 reject it as unknown, and don't need it).
ALLOW_MISMATCH=""
if [ "${GFORTRAN_MAJOR:-0}" -ge 10 ] 2>/dev/null; then
  ALLOW_MISMATCH="-fallow-argument-mismatch"
fi

COMMON="-g -fno-automatic -ffixed-form $ALLOW_MISMATCH -fbacktrace"
case "$VARIANT" in
  val)
    FFLAGS="$COMMON -O0"
    LDEXTRA=""
    ;;
  san)
    FFLAGS="$COMMON -O0 -fcheck=all -fbounds-check \
      -finit-real=snan -finit-integer=-2147483648 -finit-logical=true \
      -Wuninitialized -Wmaybe-uninitialized \
      -fsanitize=address,undefined -fno-omit-frame-pointer"
    LDEXTRA="-fsanitize=address,undefined"
    ;;
  san0)
    FFLAGS="$COMMON -O0 -fcheck=all -fbounds-check \
      -Wuninitialized -Wmaybe-uninitialized \
      -fsanitize=address,undefined -fno-omit-frame-pointer"
    LDEXTRA="-fsanitize=address,undefined"
    ;;
  san1)
    FFLAGS="$COMMON -O0 -fsanitize=address,undefined -fno-omit-frame-pointer"
    LDEXTRA="-fsanitize=address,undefined"
    ;;
  *)
    echo "unknown variant '$VARIANT' (want: san0 (default), san, san1, val)" >&2
    exit 2
    ;;
esac

echo "gfortran: $GFORTRAN_VERSION"
echo "variant:  $VARIANT"
echo "FFLAGS:   $FFLAGS"

# Match src/Makefile's LAPACK_LINK selection (system BLAS/LAPACK
# only, no bundled fallback -- see src/Makefile's lapack-guard).
if pkg-config --exists lapack blas 2>/dev/null; then
  LAPACK_LINK="$(pkg-config --libs lapack blas)"
elif pkg-config --exists openblas 2>/dev/null; then
  LAPACK_LINK="$(pkg-config --libs openblas)"
else
  echo "no system LAPACK/BLAS found (pkg-config lapack+blas, then openblas) -- install it, see INSTALL.md" >&2
  exit 2
fi
if [ ! -f gDKsapporo/libgDKsapporo.a ]; then
  echo "gDKsapporo/libgDKsapporo.a missing -- run 'make' in src/ first" >&2
  exit 2
fi

# Every object atomci (+ atgen's atgen.o/atlib.o) links, at -O0 -- so this
# is also unaffected by the gcc-8 wt9x.f miscompilation (src/Makefile's
# WT9X_OPT gate), which only fires at -O1+.
OBJS="ci cfpset ciai cici ciex cinewx cipt cirs citr ciutil ciwf fdopen diagk wkcore \
ciptrs setcfp setwig smat fgf3 aiigtf aiigt4 norm mynewf extap1 aiigr4 \
mcdriv mcci mcjsks mcfock mcscf0 mcscf1 mcscf2 mcscf3 mcscf4 mcadrs mcsut mcvut mchtr \
jacjac mcxut mcmain mcmcsf h1non prttcp \
trnsfm trnona ntrnpp wfetap extape exij xcfp delta convt shmsd fishl cfac fiang isp f3l \
shms afact dspcfp xwig6j wfgens aiistf shmsrc ntisqt setiad ior mjcdg wt9x setcom readia \
dcoda ctoi4 ctoi4n ctor8 mcp aiimcp bit fpl90lib clockm atgen atlib"

LOG="$OUTDIR/compile.log"
{ echo "gfortran: $GFORTRAN_VERSION"; echo "variant:  $VARIANT"; echo "FFLAGS:   $FFLAGS"; } > "$LOG"
fail=0
for o in $OBJS; do
  gfortran $FFLAGS -c "$o.f" -o "$OUTDIR/$o.o" >> "$LOG" 2>&1 || { echo "COMPILE FAIL: $o" | tee -a "$LOG"; fail=1; }
done
if [ "$VARIANT" = "san" ] || [ "$VARIANT" = "san0" ] || [ "$VARIANT" = "san1" ]; then
  gcc -g -fsanitize=address,undefined -fno-omit-frame-pointer -c iqtime.c -o "$OUTDIR/iqtime.o" >> "$LOG" 2>&1 || { echo "iqtime FAIL" | tee -a "$LOG"; fail=1; }
else
  gcc -g -O0 -c iqtime.c -o "$OUTDIR/iqtime.o" >> "$LOG" 2>&1 || { echo "iqtime FAIL" | tee -a "$LOG"; fail=1; }
fi

echo "=== compile done (fail=$fail); warnings summary ==="
grep -c -i "warning:" "$LOG" 2>/dev/null
[ "$fail" = 0 ] || { echo "compile errors present, aborting link"; exit 1; }

# Link both atomci and atgen from the same sanitized objects (-no-pie
# required on this host for -fno-automatic static storage).
ATOMCI_OBJS="ci cfpset ciai cici ciex cinewx cipt cirs citr ciutil ciwf fdopen diagk wkcore \
ciptrs setcfp setwig smat fgf3 aiigtf aiigt4 norm mynewf extap1 aiigr4 \
mcdriv mcci mcjsks mcfock mcscf0 mcscf1 mcscf2 mcscf3 mcscf4 mcadrs mcsut mcvut mchtr \
jacjac mcxut mcmain mcmcsf h1non prttcp \
trnsfm trnona ntrnpp wfetap extape exij xcfp delta convt shmsd fishl cfac fiang isp f3l \
shms afact dspcfp xwig6j wfgens aiistf shmsrc ntisqt setiad ior mjcdg wt9x setcom readia \
dcoda ctoi4 ctoi4n ctor8 mcp aiimcp bit fpl90lib clockm iqtime"
OBJFILES=""
for o in $ATOMCI_OBJS; do OBJFILES="$OBJFILES $OUTDIR/$o.o"; done
gfortran $LDEXTRA -no-pie -g -o "$OUTDIR/atomci" $OBJFILES \
    gDKsapporo/libgDKsapporo.a $LAPACK_LINK >> "$LOG" 2>&1
lk=$?
echo "atomci link exit=$lk"

gfortran $LDEXTRA -no-pie -g -o "$OUTDIR/atgen" \
    "$OUTDIR/atgen.o" "$OUTDIR/atlib.o" "$OUTDIR/fdopen.o" "$OUTDIR/iqtime.o" \
    "$OUTDIR/fpl90lib.o" "$OUTDIR/clockm.o" >> "$LOG" 2>&1
lk2=$?
echo "atgen link exit=$lk2"

# Staleness guard: a sanitizer binary silently outlives the source it was
# built from the moment anyone edits src/*.f without re-running this script.
# Record a manifest of the exact sources each
# binary was built from; scripts/atinputs/tests/ re-hashes those sources
# at test time and fails loudly -- does not skip -- on any mismatch.
if [ "$lk2" = 0 ]; then
  sha256sum atgen.f atlib.f fdopen.f fpl90lib.f clockm.f iqtime.c > "$OUTDIR/atgen.sha256"
fi
if [ "$lk" = 0 ]; then
  ATOMCI_SRC=""
  for o in $ATOMCI_OBJS; do
    [ "$o" = "iqtime" ] && continue  # iqtime.c, not iqtime.f -- added explicitly below
    ATOMCI_SRC="$ATOMCI_SRC $o.f"
  done
  sha256sum $ATOMCI_SRC iqtime.c > "$OUTDIR/atomci.sha256"
fi

ls -la "$OUTDIR/atomci" "$OUTDIR/atgen" 2>/dev/null
[ "$lk" = 0 ] && [ "$lk2" = 0 ]
