"""Native `atgen` CSF-list generation, ported to Python.
See refgen.py, excite.py, format.py for the ported pieces and
their source citations; excite.py's docstring explains the one deliberate
simplification (ATCHCK, a diagnostic-only consistency check, is not ported).
"""

from . import format as _format
from .excite import generate_doubles, generate_singles
from .refgen import build_references, build_shell_table, card5_closed_shell_text


def generate_csf(data, sgshl):
    """data: schema.validate()'s output. sgshl: constants.ATG_SGSHL_DEFAULT
    normally. Returns the CSF file text."""
    table = build_shell_table(data)
    references = build_references(data, table)
    singles = generate_singles(references, table)
    all_configs = generate_doubles(singles, table)
    closed_shell_text = card5_closed_shell_text(data['orbital'].get('frozen_core', []))
    return _format.generate_csf_text(table, closed_shell_text, references, singles,
                                      all_configs, sgshl)
