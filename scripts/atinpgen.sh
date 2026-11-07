#!/bin/bash
# atinpgen wrapper -- runs the Python input-deck/CSF generator (scripts/atinputs)
# by name, once installed.
#
# Resolves the atinputs package relative to this script's own location
# (installed under $ATOMCI_HOME/lib/atinputs), so it works regardless of
# prefix and without the source tree or PYTHONPATH set by hand. From an
# uninstalled source-tree checkout, run the module directly instead:
# `PYTHONPATH=/path/to/atomci/scripts python3 -m atinputs ...`
# (see docs/ATINPUTS_PY.md).

bindir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PYTHONPATH="$bindir/../lib${PYTHONPATH:+:$PYTHONPATH}"
exec python3 -m atinputs "$@"
