"""make_basis.py -- write the cc-pVTZ basis of an atom from PySCF's library in
ATOMCI's GTF format (cinewx.f GINPUT, read by readia/readfa): per contracted
function "<l> <nterm> <scale>", the exponents, the coefficients; fixed-point
numbers only (readfa has no exponent), lines of at most 80 columns, ending
with "))". Usage: python make_basis.py Sc sc.bas (needs PySCF; the shipped
.bas files were written with PySCF 2.14.0)."""
import sys
from decimal import Decimal

import pyscf
from pyscf import gto

el, out = sys.argv[1], sys.argv[2]
basis = gto.basis.load("cc-pvtz", el)
letters = "SPDFGHI"


def fixed(x):
    s = format(Decimal(repr(x)), "f")
    return s if "." in s else s + ".0"


def rows(vals, per=4):
    return ["    " + "  ".join(fixed(v) for v in vals[i:i + per]) for i in range(0, len(vals), per)]


lines = [f"\" {el} cc-pVTZ (PySCF {pyscf.__version__}, from the Basis Set Exchange),",
         "\" one block per contracted function"]
count = {}
for shell in basis:
    l = shell[0]
    prim = shell[1:]
    for c in range(len(prim[0]) - 1):
        p = [(r[0], r[1 + c]) for r in prim if r[1 + c] != 0.0]
        count[l] = count.get(l, 0) + 1
        lines.append(f"  {letters[l]} {len(p):2d}  1.0")
        lines += rows([e for e, _ in p]) + rows([cc for _, cc in p])
lines.append(" ))")
assert max(map(len, lines)) <= 80, max(map(len, lines))
with open(out, "w") as f:
    f.write("\n".join(lines) + "\n")
print("functions per l:", count, "pyscf", pyscf.__version__)
