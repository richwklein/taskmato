#!/usr/bin/env python3
"""Convert Xcode coverage report (xcresult) to LCOV format."""

import json
import sys
from pathlib import Path


def xcresult_to_lcov(xcresult_path: str, target_name: str = "Taskmato.app") -> str:
    """
    Convert xcresult coverage data to LCOV format.

    Args:
        xcresult_path: Path to the `xcrun xccov view --report --json` output
        target_name: Target name to extract coverage for (default: "Taskmato.app")

    Returns:
        LCOV format string
    """
    result = json.loads(Path(xcresult_path).read_text())

    target = None
    for t in result.get("targets", []):
        if t["name"] == target_name:
            target = t
            break

    if not target:
        raise ValueError(f"Target '{target_name}' not found in xcresult")

    lcov_lines = ["TN:Taskmato"]

    for file_info in target.get("files", []):
        file_path = file_info["path"]
        lcov_lines.append(f"SF:{file_path}")

        functions = file_info.get("functions", [])

        # lcov identifies a function by name alone and errors if the same
        # name starts on more than one line within a file (happens with
        # Swift closures that share a description, e.g. two distinct
        # subscript getters). Merge same-named entries under their first
        # line and sum execution counts rather than emitting duplicates.
        function_data = {}
        for func in functions:
            name = func["name"]
            if name not in function_data:
                function_data[name] = {"line": func["lineNumber"], "count": 0}
            function_data[name]["line"] = min(
                function_data[name]["line"], func["lineNumber"]
            )
            function_data[name]["count"] += func["executionCount"]

        for name, entry in function_data.items():
            lcov_lines.append(f"FN:{entry['line']},{name}")
        for name, entry in function_data.items():
            lcov_lines.append(f"FNDA:{entry['count']},{name}")

        if function_data:
            functions_hit = sum(
                1 for entry in function_data.values() if entry["count"] > 0
            )
            lcov_lines.append(f"FNF:{len(function_data)}")
            lcov_lines.append(f"FNH:{functions_hit}")

        # Map line numbers to execution counts using the per-function
        # coverage entries (xccov's --report --json has no flat `lines` array).
        line_data = {}

        for func in functions:
            line_num = func["lineNumber"]
            exec_count = func["executionCount"]

            if line_num not in line_data:
                line_data[line_num] = {"count": 0, "covered": False}

            if exec_count > 0:
                line_data[line_num]["covered"] = True
                line_data[line_num]["count"] = max(
                    line_data[line_num]["count"], exec_count
                )

        for line_num in sorted(line_data.keys()):
            line_entry = line_data[line_num]
            count = line_entry["count"] if line_entry["covered"] else 0
            lcov_lines.append(f"DA:{line_num},{count}")

        if line_data:
            file_lines = len(line_data)
            file_covered = sum(1 for ld in line_data.values() if ld["covered"])
            lcov_lines.append(f"LH:{file_covered}")
            lcov_lines.append(f"LF:{file_lines}")

        lcov_lines.append("end_of_record")

    return "\n".join(lcov_lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: xcresult-to-lcov.py <xccov-json> [target-name]", file=sys.stderr)
        sys.exit(1)

    xccov_json = sys.argv[1]
    target_name = sys.argv[2] if len(sys.argv) > 2 else "Taskmato.app"

    try:
        print(xcresult_to_lcov(xccov_json, target_name))
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
