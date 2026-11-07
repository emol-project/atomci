"""Obtaining the CSF list for a deck. `csf_source` is a tool-level CLI
choice, not an `.inp` key:

- "file"  — assume data['csf'] already exists (copied in
            by the user, e.g. from samples/atinputs/reference/).
- "atgen" — shell out to the native `atgen` binary via a generated `.atg`
            (atg.write_atg). Requires ATOMCI_HOME (or `atgen` on PATH).
- "python" — the native-atgen port: csfgen.generate_csf.
"""

import os
import shutil
import subprocess

from . import constants
from .atg import write_atg
from .csfgen import generate_csf


class CsfSourceError(Exception):
    pass


def _find_atgen():
    home = os.environ.get('ATOMCI_HOME')
    if home:
        candidate = os.path.join(home, 'bin', 'atgen')
        if os.path.isfile(candidate):
            return candidate
    found = shutil.which('atgen')
    if found:
        return found
    raise CsfSourceError(
        "could not find the 'atgen' binary: set ATOMCI_HOME (pointing at a "
        "`make install` tree) or put 'atgen' on PATH")


def _atg_path_for(data):
    stem, _ext = os.path.splitext(data['deck'])
    return f'{stem}.atg'


def obtain_csf(data, csf_source, work_dir='.'):
    """Ensures data['csf'] exists in work_dir, per csf_source. Returns the
    path to the .atg file if one was generated (csf_source == 'atgen'),
    else None."""
    csf_path = os.path.join(work_dir, data['csf'])

    if csf_source == 'file':
        if not os.path.isfile(csf_path):
            raise CsfSourceError(
                f"csf_source=file but '{data['csf']}' does not exist in "
                f"{work_dir!r} — copy it in first, or pass --csf-source atgen")
        return None

    if csf_source == 'atgen':
        atgen = _find_atgen()
        atg_text = write_atg(data)
        atg_path = os.path.join(work_dir, _atg_path_for(data))
        with open(atg_path, 'w', encoding='utf-8') as f:
            f.write(atg_text)
        with open(atg_path, encoding='utf-8') as f:
            result = subprocess.run([atgen], stdin=f, cwd=work_dir,
                                     capture_output=True, text=True)
        if result.returncode != 0:
            raise CsfSourceError(
                f"atgen exited {result.returncode} on {atg_path}:\n{result.stdout}")
        if not os.path.isfile(csf_path):
            raise CsfSourceError(
                f"atgen ran but did not produce '{data['csf']}' in {work_dir!r} "
                f"(check the .atg's OPEN directive)")
        return atg_path

    if csf_source == 'python':
        text = generate_csf(data, constants.ATG_SGSHL_DEFAULT)
        with open(csf_path, 'w', encoding='utf-8') as f:
            f.write(text)
        return None

    raise CsfSourceError(f"unknown csf_source '{csf_source}'")
