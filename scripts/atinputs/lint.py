"""Static checks. Operates on schema.validate()'s output.

Each Finding has a severity ('error' | 'warning' | 'info'). Callers decide
what to do with errors (--lint-only exits nonzero; the plain build path
refuses to emit a deck if any error-level finding is present).
"""

import os
import re
from dataclasses import dataclass

from . import constants
from .basis import read_basis, with_orbitals, BasisError
from .constants import ANGULAR_MOMENTUM_LETTERS
from .csfgen.excite import generate_doubles, generate_singles
from .csfgen.refgen import MOCCN_DEFAULTS, RefGenError, build_references, build_shell_table
from .ir import IntList
from .raw import RawError, build_raw_blocks
from .schema import pass_entries
from .sugar import basis_ntype, core_electrons, csfs_reference_line, orbital_nob, parse_occ

# src/atgen.f:3,126: MCORE=16000000/4; MCONF=(MCORE-ND)/MSCH1, where ND is
# heap already consumed by earlier arrays before the config table's own
# partition. ND is not reproduced here -- consistent with the
# design decision to not replicate Fortran heap partitioning -- so this is
# a conservative *overestimate* of the true limit (ignoring ND>0 makes the
# estimate larger than reality), erring toward not raising false-positive
# lint errors rather than under- or over-counting precisely.
_MCORE = 16_000_000 // 4


@dataclass
class Finding:
    severity: str  # 'error' | 'warning' | 'info'
    message: str


def _csf_lint(data, findings):
    """CSF-generation checks the Fortran would reject or silently mishandle
    -- Python has none of atgen's fixed dimensions or unchecked array
    writes, so these become explicit lint rules."""
    active = data['orbital'].get('active', [])
    outer = data['orbital'].get('outer', [])
    frozen_core = data['orbital'].get('frozen_core', [])
    reference = data['reference']

    active_labels = {s['label'] for s in active}
    frozen_labels = {s['label'] for s in frozen_core}

    ok = True

    # src/atlib.f's NAMSL (CARD 2's named-shell table) is CHARACTER*2 --
    # a label longer than 2 characters silently truncates on assignment,
    # dropping the kind letter. Only
    # named shells (active/frozen_core) go through NAMSL; CARD 1's
    # orbital.outer is a count per symmetry, not a per-shell label, so it
    # isn't affected. M is the kind this is unavoidable for (its lowest
    # physically-valid label, '10M', is already 3 characters), but the
    # field-width limit itself is general -- any kind numbered >=10 hits
    # it. Reject rather than replicate the truncation: an emitted deck
    # that silently renamed a shell would be strictly worse than one that
    # refuses to build.
    for label in sorted(active_labels | frozen_labels):
        if len(label) > 2:
            ok = False
            findings.append(Finding('error',
                f"shell label '{label}' exceeds native's 2-character CARD-2 "
                f"field (src/atlib.f's NAMSL is CHARACTER*2) -- native "
                f"silently truncates it, dropping the kind letter; this "
                f"shell cannot be named on CARD 2 at all"))

    # orbital.outer's '3S' means three correlating s orbitals (CARD 1), not
    # the shell 3s, so it is never compared with the active or core labels.
    # Only a second count for the same l is an error.
    outer_ls = [s['l'] for s in outer]
    for l in sorted({l for l in outer_ls if outer_ls.count(l) > 1}):
        ok = False
        findings.append(Finding('error',
            f"orbital.outer gives more than one count for "
            f"l={ANGULAR_MOMENTUM_LETTERS[l]}"))

    for cfg in reference:
        for label, count in parse_occ(cfg['occ']):
            if label not in active_labels:
                ok = False
                findings.append(Finding('error',
                    f"reference occupation '{label}*{count}' is not declared in "
                    f"orbital.active"))
                continue
            capacity = MOCCN_DEFAULTS.get(label[-1].upper())
            if capacity is not None and count > capacity:
                ok = False
                findings.append(Finding('error',
                    f"reference occupation '{label}*{count}' exceeds shell "
                    f"capacity {capacity} for kind '{label[-1].upper()}'"))

    # &MC's CSFS is CHARACTER*72 (src/mcmain.f), one array element per
    # reference configuration with no continuation across elements
    # (src/mcmcsf.f's GET_NEXT: running past column 72 mid-configuration is
    # a hard parse error, RTNCD=99 -- confirmed by direct testing against
    # gfortran 14.2.0, not inferred from the two frozen samples, which
    # never reach this length). Unlike the CSF *file* (fixed in
    # csfgen/format.py), there is no wrapping to implement here -- a
    # reference this wide simply cannot be represented in this field under
    # the native format, so this must be a hard error, not a warning.
    # Gated on 'mc' in some pass's ctrl: CSFS is only ever emitted as part
    # of an &MC block (sugar.py's build()) -- a WF/TR-only deck never
    # renders it, so flagging this unconditionally would be a false
    # positive there. reference/orbital are calculation-wide (shared
    # across every pass), so this check itself
    # still runs once, not per pass -- only the gate needs to look across
    # every pass's ctrl, since &MC could appear in any one of them. Reads
    # data['passes']/data['ctrl'] directly rather than through
    # schema.pass_entries() -- this function is also called directly in
    # tests with a hand-built, partially-populated `data` (no 'title'),
    # and the gate here doesn't need title at all.
    ctrls = [p['ctrl'] for p in data['passes']] if data.get('passes') else [data.get('ctrl', {})]
    if any('mc' in ctrl for ctrl in ctrls):
        for cfg in reference:
            line = csfs_reference_line(cfg)
            if len(line) > 72:
                ok = False
                findings.append(Finding('error',
                    f"reference occupation '{cfg['occ']}' renders to a "
                    f"{len(line)}-character CSFS line, exceeding the native "
                    f"CHARACTER*72 limit (src/mcmain.f) -- MCMCSF has no way to "
                    f"continue a reference configuration across multiple CSFS "
                    f"elements, so this reference cannot be represented in the "
                    f"&MC block; reduce its shell count or occupations"))

    # ATRGEN hardcodes the parity marker to 1 for every reference regardless
    # of its actual parity (csfgen/refgen.py) -- multiple references with
    # genuinely different (-1)^sum(l) parities would be silently treated as
    # one parity class by csfgen, a real correctness gap, not cosmetic.
    if ok and len(reference) > 1:
        parities = {
            sum(ANGULAR_MOMENTUM_LETTERS.index(label[-1].upper()) * count
                for label, count in parse_occ(cfg['occ'])) % 2
            for cfg in reference
        }
        if len(parities) > 1:
            ok = False
            findings.append(Finding('error',
                "reference configurations have inconsistent parity -- CSF "
                "generation assumes all references share one parity class"))

    if not ok:
        return
    if not reference:
        # Nothing to generate a CSF list from -- true for a deck whose &WF
        # is a raw block with an inline payload instead of a sugar-derived
        # reference (e.g. boron.inp, RULE=0 general CI).
        return
    try:
        table = build_shell_table(data)
        references = build_references(data, table)
        singles = generate_singles(references, table)
        doubles = generate_doubles(singles, table)
    except RefGenError as e:
        findings.append(Finding('error', f"CSF generation would fail: {e}"))
        return
    mconf = _MCORE // (len(table.shells) + 1 + len(references) * 4)
    if len(doubles) > mconf:
        findings.append(Finding('error',
            f"generated CSF count ({len(doubles)}) exceeds atgen's approximate "
            f"fixed-dimension limit ({mconf}); reduce orbital.outer"))


def _param(params, name):
    """Case-insensitive lookup into a raw block's params dict (keys are
    whatever case the .inp author wrote)."""
    for k, v in params.items():
        if k.lower() == name.lower():
            return v
    return None


def _raw_int_values(value):
    """A raw param's IR value (IntList of literal tokens, or a single
    literal-token string) -> a list of Python ints, or None if it isn't
    numeric. Raw params keep literal text (schema.py's RawParams), so this
    is the one place that needs the actual integers -- for arithmetic, not
    for the per-group branching this module otherwise avoids."""
    if isinstance(value, IntList):
        tokens = value.values
    elif isinstance(value, str):
        tokens = [value]
    else:
        return None
    try:
        return [int(t) for t in tokens]
    except ValueError:
        return None


def _raw_lint(raw_entries, findings, inp_path):
    """Five raw/payload lint rules, including the &TR MPOB restatement
    rule. Operates generically on one pass's raw block list (via
    raw.build_raw_blocks) -- no per-group-name branching beyond dispatching
    on payload.kind, which is data the .inp author already supplied. Called
    once per pass by lint(): &TR/&BASVC/&GET are looked up within *this*
    pass's own raw blocks only, never across passes."""
    if not raw_entries:
        return
    try:
        raw_blocks = build_raw_blocks(raw_entries, inp_path)
    except RawError as e:
        findings.append(Finding('error', f"raw block payload: {e}"))
        return
    by_group = {b.group: b for b in raw_blocks}

    # Rule: IUNIT=5 implies a payload follows, and a payload implies IUNIT=5
    # -- the one mechanism behind &AI/&WF/&BASVC payloads.
    for b in raw_blocks:
        iunit = _param(b.params, 'iunit')
        has_iunit5 = iunit is not None and str(iunit).strip() == '5'
        if has_iunit5 and b.payload is None:
            findings.append(Finding('error',
                f"&{b.group} sets IUNIT=5 but has no payload -- IUNIT=5 means card "
                f"data follows the NAMELIST group; add a payload or remove IUNIT=5."))
        elif b.payload is not None and not has_iunit5:
            findings.append(Finding('error',
                f"&{b.group} has a payload but its params do not set IUNIT=5 -- the "
                f"native reader only reads card data after IUNIT=5, so this payload "
                f"would never be consumed."))

    # Rule: &TR ITVCI=0 requires a &BASVC block; ITVCI=1 requires a &GET
    # block (docs/namelist.002 §TR).
    tr = by_group.get('TR')
    if tr is not None:
        itvci = _param(tr.params, 'itvci')
        if itvci is not None:
            itvci = str(itvci).strip()
            if itvci == '0' and 'BASVC' not in by_group:
                findings.append(Finding('error',
                    "&TR ITVCI=0 requires a &BASVC block (transformation "
                    "coefficients supplied by the user) -- none found."))
            if itvci == '1' and 'GET' not in by_group:
                findings.append(Finding('error',
                    "&TR ITVCI=1 requires a &GET block (transformation "
                    "coefficients from a previous run) -- none found."))

    # Rule: a raw &TR block must restate MPOB. TRMAIN (src/citr.f) resets
    # MPOB(1)=0 as a sentinel before every
    # &TR read; if the deck's own &TR never sets it, TRDRIV (src/cinewx.f)
    # silently substitutes an identity MO ordering instead of erroring --
    # this is the silent-wrong-output class this project treats as most
    # severe, not merely a stricter default. A sugar-built &TR always
    # supplies mpob (derived from the basis file), so this
    # only bites a raw &TR -- exactly boron's and f.stdin's
    # multi-pass &TR restatement.
    if tr is not None and _param(tr.params, 'mpob') is None:
        findings.append(Finding('error',
            "&TR has no mpob -- TRDRIV silently substitutes an identity MO "
            "ordering instead of erroring when MPOB is omitted; "
            "if identity ordering is genuinely intended, state it "
            "explicitly rather than relying on the omission."))

    # Rule: a raw &TR block setting NPFLG!=0 crashes. TRDRIV's debug dump,
    # gated by the documented &TR NPFLG,
    # reads NFTRX -- nothing populates it under this codebase's own default
    # ITRNS=2, and the only other value tested (ITRNS!=2) crashes first for
    # an unrelated reason before ever reaching NPFLG's own
    # branch. So NPFLG!=0 is unconditionally unsafe today, regardless of
    # ITRNS. A sugar-built &TR never sets NPFLG at all (native default 0,
    # safe), so this only bites a raw &TR.
    if tr is not None:
        npflg = _raw_int_values(_param(tr.params, 'npflg'))
        if npflg is not None and any(v != 0 for v in npflg):
            findings.append(Finding('error',
                "&TR sets NPFLG!=0 -- this crashes today regardless of ITRNS: "
                "TRDRIV's debug dump reads "
                "NFTRX, which nothing populates under this codebase's own "
                "default transformation path."))

    nob = _raw_int_values(_param(tr.params, 'nob')) if tr is not None else None
    nbf = _raw_int_values(_param(tr.params, 'nbf')) if tr is not None else None
    block_sizes = ([n * f for n, f in zip(nob, nbf)]
                    if nob is not None and nbf is not None and len(nob) == len(nbf)
                    else None)

    for b in raw_blocks:
        if b.payload is None:
            continue
        kind = b.payload.kind
        text_lines = [ln.rstrip() for ln in b.payload.lines]
        non_blank = [ln for ln in text_lines if ln.strip()]

        if kind in ('basis', 'csf'):
            # &AI/&WF payload readers (AIISTF/GINPUT, WFGENS) need at
            # least one real ')' to terminate the shell/config list --
            # under-closing desyncs the input stream rather than erroring
            # cleanly.
            last = non_blank[-1].strip() if non_blank else ''
            if not last or any(c != ')' for c in last):
                findings.append(Finding('error',
                    f"&{b.group} payload (kind: {kind}) does not end with a "
                    f"closing ')' line -- the native reader (AIISTF/GINPUT for "
                    f"'basis', WFGENS for 'csf') needs at least one to end the "
                    f"list; without it, it walks into whatever text follows "
                    f"(the next NAMELIST card) as if it were more data."))

        elif kind == 'vectors':
            # CARDVC (&BASVC's reader) reads exactly one ')' per non-empty
            # NOB[i]*NBF[i] symmetry block and nothing more
            # (docs/namelist.002's claim of a further ')))' outer
            # terminator does not match the code). A block-ending line
            # ends in exactly one ')', not a run of several (a run is the
            # shipped deck's harmless-but-inert filler convention, not a
            # per-symmetry terminator).
            block_endings = sum(1 for ln in non_blank if re.search(r'(?<!\))\)$', ln))
            if block_sizes is not None:
                expected = sum(1 for s in block_sizes if s != 0)
                if block_endings != expected:
                    findings.append(Finding('error',
                        f"&{b.group} payload has {block_endings} per-symmetry "
                        f"closing-')' lines, expected {expected} (one per non-empty "
                        f"NOB[i]*NBF[i] symmetry in &TR) -- CARDVC reads exactly "
                        f"one ')' per symmetry block and nothing more; a mismatch "
                        f"here can silently misassign vectors to the wrong "
                        f"symmetry rather than error."))

            # &BASVC coefficient count = sum(NOB[i]*NBF[i]) -- the most
            # valuable of these rules, catching a truncated or
            # mis-transcribed vector block before a run that would
            # otherwise fail obscurely deep inside the CI.
            if block_sizes is not None:
                expected_total = sum(block_sizes)
                actual_total = len(' '.join(text_lines).replace(')', ' ').split())
                if actual_total != expected_total:
                    findings.append(Finding('error',
                        f"&{b.group} payload has {actual_total} numeric tokens, "
                        f"expected {expected_total} (sum of NOB[i]*NBF[i] from "
                        f"&TR) -- CARDVC's own sanity check on this can be "
                        f"satisfied by coincidence on a miscount, silently "
                        f"misassigning coefficients."))


def _ind_lint(rows, counts, where, findings):
    """IND quartets (record, l, first, last) should cover orbitals
    1..counts[l] of every symmetry exactly once (docs/namelist.002 &GET:
    'all the needed orbital coefficients are accounted for'). What GETVCA
    does with a gap has not been traced, so a gap is a warning; a row
    outside the basis is an error."""
    covered = {}
    for row in rows:
        l = row['l']
        if l < 0 or l >= len(counts):
            findings.append(Finding('error',
                f"{where}: l={l} is not a symmetry of the basis (0..{len(counts) - 1})"))
            continue
        if row['record'] < 1 or row['first'] < 1 or row['last'] < row['first']:
            findings.append(Finding('error',
                f"{where}: row (record={row['record']}, l={l}, first={row['first']}, "
                f"last={row['last']}) is not a valid range"))
            continue
        covered.setdefault(l, []).extend(range(row['first'], row['last'] + 1))
    for l, k in enumerate(counts):
        got = sorted(covered.get(l, []))
        if got != list(range(1, k + 1)):
            findings.append(Finding('warning',
                f"{where}: the rows for l={l} cover orbitals "
                f"{_ranges(got) or 'none'}, but symmetry {l + 1} needs 1-{k}"
                if k else
                f"{where}: rows for l={l} given, but symmetry {l + 1} has no orbitals"))


def _ranges(values):
    """[1,2,3,5] -> '1-3,5' (with repeats shown as they are)."""
    out = []
    for v in values:
        if out and v == out[-1][1] + 1:
            out[-1][1] = v
        else:
            out.append([v, v])
    return ','.join(f'{a}-{b}' if a != b else f'{a}' for a, b in out)


def _pass_lint(ctrl, raw_entries, findings, inp_path, nob=None, nbf=None):
    """Checks scoped to a single pass's own ctrl/raw: no cross-pass state,
    so each pass is checked in complete isolation -- a pass with no &RS is
    flagged even if an earlier pass had one, since NRNFG.rs literally is
    per-pass and nothing carries. nob/nbf: the orbitals and basis
    functions per symmetry, when the basis file could be read."""
    if 'tr' in ctrl:
        tr = ctrl['tr']
        if 'input_unit' in tr:
            findings.append(Finding('error',
                "ctrl.tr.input_unit is specified: this emits &TR NFAII equal to "
                "it, which collides with &GET IVCS=27 and causes a SIGFPE "
                "(exit 136) in TRMAIN. Omit it to keep the safe default NFAII=18."))
        if tr.get('ind') and 'from_record' in tr:
            findings.append(Finding('error',
                "ctrl.tr gives both ind and from_record; give one of them."))
        elif not tr.get('ind') and 'from_record' not in tr:
            findings.append(Finding('error',
                "ctrl.tr is present but has neither ind nor from_record: &GET "
                "would have NIND=0, which stops TRMAIN with an end-of-file "
                "error (RDCP)."))
        elif tr.get('ind') and nob is not None:
            _ind_lint(tr['ind'], nob, 'ctrl.tr.ind', findings)

    if 'mc' in ctrl and ctrl['mc'].get('ind') and nbf is not None:
        # MCMAIN's starting orbitals come from the whole basis (NBF), not
        # from the orbitals of the CI.
        _ind_lint(ctrl['mc']['ind'], nbf, 'ctrl.mc.ind', findings)

    if 'ci' in ctrl and 'ioflg' in ctrl['ci']:
        ioflg = ctrl['ci']['ioflg']
        if len(ioflg) > 6:
            findings.append(Finding('error',
                f"ctrl.ci.ioflg has {len(ioflg)} values; &CI IOFLG has 6"))
        elif len(ioflg) >= 3:
            vec, dens = ioflg[1], ioflg[2]
            # docs/namelist.002 &CI IOFLG: CI vectors and density matrices go
            # to the same file, and (n, n), (n, 0), (0, n) are listed as
            # invalid: when both are written, both must be 0 (append).
            if vec >= 0 and dens >= 0 and (vec, dens) != (0, 0):
                findings.append(Finding('error',
                    f"ctrl.ci.ioflg: IOFLG(2)={vec} with IOFLG(3)={dens} is invalid "
                    f"(both go to the same file; when both are saved, both must "
                    f"be 0, append)"))

    raw_groups = {entry['group'].upper() for entry in raw_entries}
    if 'rs' not in ctrl and 'RS' not in raw_groups:
        findings.append(Finding('warning',
            "ctrl.rs is missing: the run will complete but no SD-CI ENERGY "
            "summary will be printed."))

    if 'wf' in ctrl:
        rule = ctrl['wf']['rule']
        preset = constants.NRNFG_PRESET_BY_RULE.get(rule)
        if preset is not None:
            actual = tuple(1 if step in ctrl else 0 for step in constants.CTRL_STEP_ORDER)
            # RULE only constrains the slots that actually differ across
            # NRNFG_PRESET_BY_RULE's three presets (PT and EX -- the other
            # six slots are identical in every preset, so they carry no
            # information about RULE). Comparing all eight, as this used to,
            # flagged independent user choices as RULE mismatches -- e.g.
            # fpt.inp sets NRNFG(2)=0 (MC) because it reuses f's natural
            # orbitals via f.NO instead of running MCSCF, which has nothing
            # to do with RULE.
            varying = [i for i in range(len(preset))
                       if len({p[i] for p in constants.NRNFG_PRESET_BY_RULE.values()}) > 1]
            mismatched = [constants.CTRL_STEP_ORDER[i] for i in varying if actual[i] != preset[i]]
            if mismatched:
                findings.append(Finding('warning',
                    f"NRNFG {list(actual)} does not match the standard preset "
                    f"{list(preset)} for &WF RULE={rule} (slot(s) {mismatched} disagree)"))

    _raw_lint(raw_entries, findings, inp_path)


def lint(data, basis_dir='.', inp_path='.'):
    findings = []

    basis = None
    if 'basis' in data['files']:
        try:
            basis = read_basis(os.path.join(basis_dir, data['files']['basis']),
                               basis_ntype(data))
        except (BasisError, OSError) as e:
            findings.append(Finding('error', f"could not read basis file: {e}"))

    nob = None
    if basis is not None:
        nob = orbital_nob(data, basis)
        for l, (k, n) in enumerate(zip(nob, basis.nbf)):
            if k > n:
                findings.append(Finding('error',
                    f"symmetry {l + 1} ({ANGULAR_MOMENTUM_LETTERS[l]}): the core, "
                    f"active and orbital.outer orbitals need {k} orbitals, but "
                    f"the basis has only {n} functions"))
        outer_ls = {s['l'] for s in data['orbital'].get('outer', [])}
        if outer_ls:
            for l, k in enumerate(nob):
                if k == 0:
                    # Observed 2026-11-03 (B, STF basis with h and i
                    # functions, outer up to g): TRMAIN runs, CIMAIN stops
                    # with return code 7120 (CIDRIV 7135).
                    findings.append(Finding('error',
                        f"symmetry {l + 1} ({ANGULAR_MOMENTUM_LETTERS[l]}) of the basis "
                        f"has no orbital in the CI (NOB=0), which stops CIMAIN "
                        f"(return code 7120); give at least one "
                        f"{ANGULAR_MOMENTUM_LETTERS[l]} orbital in orbital.outer, or "
                        f"remove the {ANGULAR_MOMENTUM_LETTERS[l].lower()} functions "
                        f"from the basis"))
        for s in data['orbital'].get('outer', []):
            if s['l'] >= basis.nsym:
                findings.append(Finding('error',
                    f"orbital.outer gives {s['label']}, but the basis has no "
                    f"{ANGULAR_MOMENTUM_LETTERS[s['l']]} functions"))
        if outer_ls and any(k > 0 for k in nob) and nob != basis.nbf:
            findings.append(Finding('info',
                f"NOB {nob} < NBF {basis.nbf}: the CI uses the first NOB "
                f"vectors of each symmetry of the coefficient set"))
        basis = with_orbitals(basis, [min(k, n) for k, n in zip(nob, basis.nbf)])

    for entry in pass_entries(data):
        _pass_lint(entry['ctrl'], entry.get('raw', []), findings, inp_path,
                   nob=basis.nob if basis is not None else None,
                   nbf=basis.nbf if basis is not None else None)

    if basis is not None:
        if basis.nsym != len(basis.nbf) or basis.nsym != len(basis.nob):
            findings.append(Finding('error',
                f"NSYM ({basis.nsym}) does not match len(NBF) ({len(basis.nbf)}) "
                f"or len(NOB) ({len(basis.nob)})"))
        for i, (nob_i, mpob_i) in enumerate(zip(basis.nob, basis.mpob), start=1):
            if len(mpob_i) != nob_i:
                findings.append(Finding('error',
                    f"len(MPOB[{i}]) ({len(mpob_i)}) does not match NOB[{i}] ({nob_i})"))

    frozen_core = data['orbital'].get('frozen_core', [])
    reference = data['reference']
    itnels = {core_electrons(frozen_core) + sum(count for _l, count in parse_occ(cfg['occ']))
              for cfg in reference}
    if len(itnels) > 1:
        findings.append(Finding('error',
            f"reference configurations disagree on total electron count: "
            f"{sorted(itnels)}"))

    if len(itnels) == 1:
        itnel = next(iter(itnels))
        if itnel != data['atom']['z']:
            findings.append(Finding('info',
                f"atom.z ({data['atom']['z']}) does not equal the derived ITNEL "
                f"({itnel}) — fine if this is an ion"))

    _csf_lint(data, findings)

    return findings
