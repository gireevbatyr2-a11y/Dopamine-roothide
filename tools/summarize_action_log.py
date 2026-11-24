import argparse
import json
import re
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
PREFIX = re.compile(r"^.*?\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z\s?")
DIAG = re.compile(r"^(.*?):(\d+):(\d+):\s+(warning|error):\s+(.*)$")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    log_path = Path(args.log)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    warning_rows = []
    error_rows = []
    generic_warnings = []
    test_markers = []
    build_markers = []
    for number, raw in enumerate(log_path.read_text(errors="replace").splitlines(), 1):
        line = ANSI.sub("", raw)
        line = PREFIX.sub("", line)
        if "warning:" in line:
            match = DIAG.match(line)
            if match and match.group(4) == "warning":
                warning_rows.append({"line": number, "path": match.group(1), "source_line": int(match.group(2)), "column": int(match.group(3)), "message": match.group(5)})
            else:
                generic_warnings.append({"line": number, "message": line.strip()})
        match = DIAG.match(line)
        if match and match.group(4) == "error":
            error_rows.append({"line": number, "path": match.group(1), "source_line": int(match.group(2)), "column": int(match.group(3)), "message": match.group(5)})
        if re.search(r"Test Suite|Test Case|Testing failed|Executed \d+ tests?", line, re.I):
            test_markers.append({"line": number, "message": line.strip()})
        if re.search(r"BUILD SUCCEEDED|BUILD FAILED|ARCHIVE SUCCEEDED|ARCHIVE FAILED", line):
            build_markers.append({"line": number, "message": line.strip()})
    unique_warnings = sorted({(x["path"], x["source_line"], x["message"]) for x in warning_rows})
    report = {
        "log": str(log_path),
        "line_count": len(log_path.read_text(errors="replace").splitlines()),
        "warning_diagnostic_lines": len(warning_rows),
        "unique_warning_diagnostics": len(unique_warnings),
        "generic_warning_lines": generic_warnings,
        "error_diagnostic_lines": error_rows,
        "build_markers": build_markers,
        "test_markers": test_markers,
        "test_markers_interpretation": "No test command or test execution markers found in the original workflow log." if not test_markers else "Test-like markers present; inspect exact lines.",
    }
    (out / "diagnostics.json").write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n")
    rows = ["path\tsource_line\tmessage\tlog_line"]
    rows.extend("\t".join(str(x[k]) for k in ("path", "source_line", "message", "line")) for x in warning_rows)
    (out / "warnings.tsv").write_text("\n".join(rows) + "\n")
    print(json.dumps({k: report[k] for k in ("line_count", "warning_diagnostic_lines", "unique_warning_diagnostics", "error_diagnostic_lines", "build_markers", "test_markers")}, indent=2))


if __name__ == "__main__":
    main()
