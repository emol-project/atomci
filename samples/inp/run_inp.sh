#!/bin/bash
# run_inp.sh -- generate the deck of each .inp in this directory with
# atinpgen, run atomci on it, and compare the energy with the answer.
#
#   ATOMCI_HOME=... ./run_inp.sh [boron boron_nsdim700 f fpt sc ti cu be c]
#   INP_WORK   work root (default ./work); every run keeps its files in
#              <INP_WORK>/<name>/ (f and fpt share <INP_WORK>/f/)
#
# Prints one line per calculation: OK or FAIL, the expected and the
# computed energies. Exit status 0 when every calculation is OK.
set -u
here=$(cd "$(dirname "$0")" && pwd)
: "${ATOMCI_HOME:?set ATOMCI_HOME to the installed ATOMCI (make install)}"
root=${INP_WORK:-$here/work}

# name -> expected energies (in the order the listing prints them)
declare -A want=(
    [boron]="-24.6461953967"
    [boron_nsdim700]="-24.6461953996"
    [f]="-99.641223 -99.641037 -99.641037"
    [fpt]="-99.640355"
    [sc]="-759.776305"
    [ti]="-848.458805"
    [cu]="-1639.376374"
    [be]="-14.618544"
    [c]="-37.779409"
)
# name -> basis file to copy into the work directory
declare -A basis=([f]=f.bas [fpt]=f.bas [sc]=sc.bas [ti]=ti.bas [cu]=cu.bas [be]=be.bas [c]=c.bas)

computed() { # listing name
    case $2 in
        boron*) grep -a -E '^ +ET += ' "$1" | tail -1 | awk '{print $NF}' ;;
        *)      grep -a 'SD-CI ENERGY  ' "$1" | awk '{print $NF}' | tr '\n' ' ' | sed 's/ $//' ;;
    esac
}

fail=0
for name in ${@:-boron boron_nsdim700 f fpt sc ti cu be c}; do
    w=$root/$name
    [ "$name" = fpt ] && w=$root/f          # fpt reads f.NO from the f run
    if [ "$name" != fpt ]; then rm -rf "$w"; fi
    mkdir -p "$w" && cd "$w"
    ln -sf "$ATOMCI_HOME/CFPTBL" CFPTBL
    [ -n "${basis[$name]:-}" ] && cp "$here/${basis[$name]}" .
    if ! "$ATOMCI_HOME/bin/atinpgen" "$here/$name.inp" > "$name.gen.log" 2>&1; then
        echo "FAIL $name: atinpgen failed (see $w/$name.gen.log)"; fail=1; continue
    fi
    "$ATOMCI_HOME/bin/atomci" < "$name.deck" > "$name.output" 2> "$name.err"
    got=$(computed "$name.output" "$name")
    bad=$(grep -a 'RETURN CODE IS' "$name.output" | grep -vc 'RETURN CODE IS    0')
    if [ "$got" = "${want[$name]}" ] && [ "$bad" = 0 ] && [ ! -s "$name.err" ]; then
        echo "OK   $name: ${want[$name]}"
    else
        echo "FAIL $name: expected ${want[$name]}, got '${got}'" \
             "(non-zero return codes: $bad; stderr: $w/$name.err)"
        fail=1
    fi
done
exit $fail
