#!/bin/bash
# Native atomci wrapper.  Requires ATOMCI_HOME (the install prefix) to be set in
# your environment -- `make install` prints the exact `export ATOMCI_HOME=...`
# line to use.  Runs the installed binary in the current working directory
# (where CFPTBL and the run's input/scratch files live).

if [ -z "$ATOMCI_HOME" ]; then
    echo "atomci.sh: ATOMCI_HOME is not set." >&2
    echo "  Set it to your install prefix, e.g.: export ATOMCI_HOME=/path/to/local" >&2
    exit 1
fi

exec "$ATOMCI_HOME/bin/atomci" "$@"
