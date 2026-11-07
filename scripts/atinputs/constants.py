"""Values the Java version (msekiya.jar) fixes.

A future input-format revision may expose some of these directly; keeping
them here means that would be a one-file change.
"""

# &CI NRNFG(6) — the six CIMAIN sections. msekiya.jar hard-codes this
# regardless of RULE; it is also the native default (docs/namelist.002).
CI_NRNFG = (1, 1, 1, 0, 1, 1)

# &CI IOFLG(5) — save directive: append-and-save the NO (unit 27),
# do not save CI vectors or density matrices.
CI_IOFLG = (0, -1, -1, 0, 0)

# &RS RULE — Brown's formula (RULE=2 in docs/namelist.002 §RS).
RS_RULE = 2

# &RS NRNFG is never emitted by the jar, so it defaults to 0 (native
# default). fpt.stdin (hand-written) uses NRNFG=1 to get the
# rejected-CSF energy-correction estimate; the jar-generated deck omits
# it. This is the Java version's documented fidelity gap.
RS_NRNFG_EMITTED = False

# &GET IVCS — unit number of the natural-orbital save file to extract
# transformation coefficients from.
GET_IVCS = 27

# &AI / &TR NFAII — default &TR NFAII (native default 18). Colliding
# with &GET IVCS=27 by setting ctrl.tr.input_unit=27 causes a SIGFPE
# in TRMAIN (see lint.py).
TR_NFAII_DEFAULT = 18

# &MC IVCS — default MCSCF orbital-save unit (native default 27). Not
# emitted by the jar; kept here for documentation and for lint checks.
MC_IVCS_DEFAULT = 27

# &MC NSET — not documented elsewhere, but confirmed
# hard-coded from the frozen f.deck (native default is 0; the jar always
# emits 1, append-mode save of the converged SCF orbitals).
MC_NSET = 1

# &TR ITVCI — input mode for transformation coefficients (0 = inline
# &BASVC, 1 = from a previous run's &GET). &BASVC has no XML/schema
# binding at all, so 1 is the only
# usable value; the jar defaults to it even when ctrl.tr.record is
# omitted (confirmed: f.xml has no <tr record> yet f.deck has ITVCI=1).
TR_ITVCI_DEFAULT = 1

# Fixed I/O unit numbers baked into every generated deck (confirmed from
# both frozen decks; none of these has an XML/schema "unit" attribute).
CFPTBL_UNIT = 10
AI_BASIS_UNIT = 3
WF_CSF_UNIT = 2
MCP_UNIT = 44

# &CNTL NRNFG(8) presets keyed by &WF RULE, per docs/namelist.002 §WF.
# Used by lint.py to warn when the derived NRNFG
# disagrees with the preset for the chosen RULE.
NRNFG_PRESET_BY_RULE = {
    0: (1, 1, 1, 1, 0, 1, 1, 1),
    1: (1, 1, 1, 1, 0, 0, 1, 1),
    2: (1, 1, 1, 1, 1, 1, 1, 1),
}

# Order of <ctrl> child keys -> &CNTL NRNFG slot (docs/ATINPUTS_MANUAL.md).
# Present -> 1, absent -> 0.
CTRL_STEP_ORDER = ("ai", "mc", "wf", "tr", "pt", "ex", "ci", "rs")

# Spectroscopic angular-momentum letters, indexed by l (0-based). Skips
# 'J' by convention. Used for atom.ang and the n/l shorthand notation
# (frozen_core/active/outer, e.g. "11S", "6D").
ANGULAR_MOMENTUM_LETTERS = "SPDFGHIKLMNOQRTUVWXYZ"

# --- .atg (atgen input) hard-coded values ---------------------------------
# Both worked samples (samples/native/f.atg, fpt.atg) agree on these; kept as
# constants until a differential-sweep case demonstrates a need to expose
# them in the .inp schema.

# atgen's .atg OPEN header always assigns the CSF output to unit 7.
ATG_CSF_UNIT = 7

# CARD 6 (SGSHL): both samples use -1 ("plain negative, no extra option" —
# see the atgen.f:513-541 source read in the atg.py docstring). Values
# outside -9..-1 change which excitation orders get generated at all, so
# this is a real behavioral choice, not cosmetic — but SD-CI (single +
# double excitations, no extra options) is what this generator targets throughout.
ATG_SGSHL_DEFAULT = -1
