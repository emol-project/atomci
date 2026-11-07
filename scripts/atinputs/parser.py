"""Hand-written parser for the .inp format.

Nesting is by indentation (spaces only, exactly 2 per level). The parser
never infers types: every leaf value is captured as a RawValue
(raw text + source location). Whether a leaf is a plain string or an
inline record is decided later by schema.py, the
only place that knows a key's declared type.

Node shapes produced by parse():
  Mapping -> dict subclass {key: Node}, with a .line for error reporting
  List    -> list subclass [Node], with a .line for error reporting
  Leaf    -> RawValue
"""

from dataclasses import dataclass


class ParseError(Exception):
    def __init__(self, message, filename, line):
        self.message = message
        self.filename = filename
        self.line = line
        super().__init__(f"{filename}:{line}: {message}")


class Mapping(dict):
    """A nested block parsed as key: value pairs. Subclasses dict so
    isinstance(node, dict) still holds; .line is the line of the 'key:'
    that introduced this block (or 1 for the document root)."""

    def __init__(self, *args, line=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.line = line


class NodeList(list):
    """A nested block parsed as '-' list items. Subclasses list; .line is
    the line of the 'key:' that introduced this block."""

    def __init__(self, *args, line=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.line = line


@dataclass
class RawValue:
    text: str  # raw value text: comment stripped, not yet dequoted or split
    filename: str
    line: int

    def scalar(self):
        """Interpret as a single string value (quote-aware dequoting)."""
        return _dequote(self.text.strip())

    def record(self):
        """Interpret as an inline record: split on top-level commas, then
        each field on its first top-level colon. Returns {key: RawValue}."""
        fields = {}
        for segment in _split_top_level(self.text, ','):
            segment = segment.strip()
            if not segment:
                continue
            idx = _find_top_level(segment, ':')
            if idx < 0:
                raise ParseError(
                    f"expected 'key: value' in inline record, got '{segment}'",
                    self.filename, self.line,
                )
            key = segment[:idx].strip()
            fields[key] = RawValue(segment[idx + 1:], self.filename, self.line)
        return fields


def parse_file(path):
    with open(path, encoding='utf-8') as f:
        text = f.read()
    return parse(text, path)


def parse(text, filename):
    lines = _logical_lines(text, filename)
    mapping, i = _parse_mapping(lines, 0, 0, filename, line=1)
    if i != len(lines):
        raise ParseError('unexpected indentation', filename, lines[i][2])
    return mapping


# --- quote-aware scanning ---------------------------------------------

def _strip_comment(line):
    """Return line truncated at the first unquoted '#'. Quotes are left
    in place (not resolved) so later stages can still dequote them."""
    in_quotes = False
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if c == '\\' and in_quotes and i + 1 < n and line[i + 1] in ('"', '\\'):
            i += 2
            continue
        if c == '"':
            in_quotes = not in_quotes
            i += 1
            continue
        if c == '#' and not in_quotes:
            return line[:i]
        i += 1
    return line


def _find_top_level(text, char):
    in_quotes = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '\\' and in_quotes and i + 1 < n and text[i + 1] in ('"', '\\'):
            i += 2
            continue
        if c == '"':
            in_quotes = not in_quotes
            i += 1
            continue
        if c == char and not in_quotes:
            return i
        i += 1
    return -1


def _split_top_level(text, sep):
    parts = []
    start = 0
    in_quotes = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '\\' and in_quotes and i + 1 < n and text[i + 1] in ('"', '\\'):
            i += 2
            continue
        if c == '"':
            in_quotes = not in_quotes
            i += 1
            continue
        if c == sep and not in_quotes:
            parts.append(text[start:i])
            start = i + 1
        i += 1
    parts.append(text[start:])
    return parts


def _dequote(text):
    """text has already had outer whitespace stripped. Remove quote
    delimiters, resolve \\" and \\\\, pass everything else through."""
    out = []
    in_quotes = False
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '\\' and in_quotes and i + 1 < n and text[i + 1] in ('"', '\\'):
            out.append(text[i + 1])
            i += 2
            continue
        if c == '"':
            in_quotes = not in_quotes
            i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


# --- indentation / line structure --------------------------------------

def _logical_lines(text, filename):
    """Comments and blank lines removed. Returns [(indent, body, lineno)]."""
    lines = []
    for lineno, raw in enumerate(text.splitlines(), start=1):
        content = _strip_comment(raw)
        if content.strip() == '':
            continue
        lead = len(content) - len(content.lstrip(' \t'))
        indent_str = content[:lead]
        if '\t' in indent_str:
            raise ParseError('indentation contains a tab', filename, lineno)
        body = content[lead:].rstrip()
        if body == '':
            continue
        lines.append((lead, body, lineno))
    return lines


def _parse_mapping(lines, i, indent, filename, line=None):
    result = Mapping(line=line)
    while i < len(lines) and lines[i][0] == indent:
        _cur_indent, content, lineno = lines[i]
        if content.startswith('-'):
            raise ParseError(
                "expected 'key: value', found a list item ('-') at mapping level",
                filename, lineno)
        idx = _find_top_level(content, ':')
        if idx < 0:
            raise ParseError(f"expected ':' after key in '{content}'", filename, lineno)
        key = content[:idx].strip()
        rest = content[idx + 1:]
        i += 1
        if rest.strip() == '':
            if i < len(lines) and lines[i][0] > indent:
                child_indent = lines[i][0]
                if child_indent != indent + 2:
                    raise ParseError(
                        f"indentation under '{key}' must be {indent + 2} spaces "
                        f"(got {child_indent})",
                        filename, lines[i][2])
                if lines[i][1].startswith('-'):
                    node, i = _parse_list(lines, i, child_indent, filename, line=lineno)
                else:
                    node, i = _parse_mapping(lines, i, child_indent, filename, line=lineno)
                result[key] = node
            else:
                result[key] = RawValue('', filename, lineno)
        else:
            result[key] = RawValue(rest, filename, lineno)
    return result, i


def _parse_list(lines, i, indent, filename, line=None):
    items = NodeList(line=line)
    while i < len(lines) and lines[i][0] == indent and lines[i][1].startswith('-'):
        _cur_indent, content, lineno = lines[i]
        item_text = content[1:].lstrip()
        i += 1
        if item_text.strip() == '':
            if i < len(lines) and lines[i][0] > indent:
                child_indent = lines[i][0]
                if child_indent != indent + 2:
                    raise ParseError(
                        f"indentation under list item must be {indent + 2} spaces "
                        f"(got {child_indent})",
                        filename, lines[i][2])
                node, i = _parse_mapping(lines, i, child_indent, filename, line=lineno)
                items.append(node)
            else:
                items.append(RawValue('', filename, lineno))
        else:
            items.append(RawValue(item_text, filename, lineno))
    return items, i
