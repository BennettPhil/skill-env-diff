#!/usr/bin/env python3
"""env-diff: Compare .env files and show missing, extra, and different variables."""

import argparse
import json
import os
import sys
from collections import OrderedDict


def parse_env_file(filepath):
    """Parse a .env file and return an OrderedDict of key-value pairs.

    Handles:
    - Comments (lines starting with #)
    - Empty lines
    - Quoted values (single and double quotes)
    - Empty values (KEY=)
    - Lines without = (skipped)
    - Trailing whitespace
    - BOM (byte order mark)
    """
    env = OrderedDict()

    if not os.path.isfile(filepath):
        print(f"Error: File not found: {filepath}", file=sys.stderr)
        sys.exit(2)

    try:
        with open(filepath, "r", encoding="utf-8-sig") as f:
            for line_num, raw_line in enumerate(f, 1):
                line = raw_line.rstrip("\n\r")
                # Strip trailing whitespace
                line = line.rstrip()
                # Skip empty lines and comments
                if not line or line.lstrip().startswith("#"):
                    continue
                # Skip lines without =
                if "=" not in line:
                    continue
                # Split on first =
                key, _, value = line.partition("=")
                key = key.strip()
                # Skip empty keys
                if not key:
                    continue
                # Handle quoted values
                value = value.strip()
                if len(value) >= 2:
                    if (value.startswith('"') and value.endswith('"')) or \
                       (value.startswith("'") and value.endswith("'")):
                        value = value[1:-1]
                env[key] = value
    except (IOError, OSError) as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)
        sys.exit(2)

    return env


def mask_value(value):
    """Mask a value for security: show first and last char if long enough."""
    if len(value) <= 2:
        return "***"
    return value[0] + "***" + value[-1]


def compare_envs(file_envs, base_file=None, show_values=False):
    """Compare parsed env dicts and return a structured result.

    Args:
        file_envs: list of (filename, OrderedDict) tuples
        base_file: if set, compare all files against this base
        show_values: whether to show actual values or masked

    Returns:
        dict with comparison results and a bool indicating if all are in sync
    """
    all_keys = OrderedDict()
    for fname, env in file_envs:
        for key in env:
            if key not in all_keys:
                all_keys[key] = []
            all_keys[key].append(fname)

    filenames = [fname for fname, _ in file_envs]
    env_map = {fname: env for fname, env in file_envs}

    results = {
        "files": filenames,
        "missing": [],    # keys missing from some files
        "extra": [],      # keys only in some files (relative to base)
        "different": [],   # keys with different values
        "ok": [],          # keys present in all files with same value
    }

    has_diff = False

    if base_file:
        # Compare all others against the base
        base_env = env_map[base_file]
        other_files = [f for f in filenames if f != base_file]

        for key in all_keys:
            in_base = key in base_env

            if in_base:
                # Check which other files are missing this key
                missing_from = [f for f in other_files if key not in env_map[f]]
                if missing_from:
                    has_diff = True
                    entry = {"key": key, "missing_from": missing_from, "present_in": base_file}
                    results["missing"].append(entry)
                else:
                    # All files have it; check values
                    base_val = base_env[key]
                    diff_files = []
                    for f in other_files:
                        if env_map[f][key] != base_val:
                            diff_files.append(f)
                    if diff_files:
                        has_diff = True
                        entry = {"key": key, "files": {}}
                        for f in filenames:
                            if key in env_map[f]:
                                val = env_map[f][key]
                                entry["files"][f] = val if show_values else mask_value(val)
                        results["different"].append(entry)
                    else:
                        results["ok"].append(key)
            else:
                # Key not in base but in some other files => extra
                has_diff = True
                present_in = [f for f in other_files if key in env_map[f]]
                entry = {"key": key, "extra_in": present_in, "not_in": base_file}
                results["extra"].append(entry)
    else:
        # Pairwise: compare all files against each other
        for key in all_keys:
            present_in = [f for f in filenames if key in env_map[f]]
            missing_from = [f for f in filenames if key not in env_map[f]]

            if missing_from:
                has_diff = True
                entry = {"key": key, "present_in": present_in, "missing_from": missing_from}
                results["missing"].append(entry)
            else:
                # All files have it; check values
                values = [env_map[f][key] for f in filenames]
                if len(set(values)) > 1:
                    has_diff = True
                    entry = {"key": key, "files": {}}
                    for f in filenames:
                        val = env_map[f][key]
                        entry["files"][f] = val if show_values else mask_value(val)
                    results["different"].append(entry)
                else:
                    results["ok"].append(key)

    return results, has_diff


def format_text(results, has_diff):
    """Format results as human-readable text."""
    lines = []
    filenames = results["files"]

    lines.append(f"Comparing: {', '.join(filenames)}")
    lines.append("")

    if not has_diff:
        lines.append("All files are in sync.")
        ok_count = len(results["ok"])
        if ok_count > 0:
            lines.append(f"{ok_count} variable(s) present in all files with matching values.")
        return "\n".join(lines)

    if results["missing"]:
        lines.append("MISSING KEYS:")
        for entry in results["missing"]:
            key = entry["key"]
            missing_from = ", ".join(entry["missing_from"])
            if "present_in" in entry:
                if isinstance(entry["present_in"], list):
                    present_in = ", ".join(entry["present_in"])
                else:
                    present_in = entry["present_in"]
            else:
                present_in = "other files"
            lines.append(f"  {key}")
            lines.append(f"    present in: {present_in}")
            lines.append(f"    missing from: {missing_from}")
        lines.append("")

    if results["extra"]:
        lines.append("EXTRA KEYS:")
        for entry in results["extra"]:
            key = entry["key"]
            extra_in = ", ".join(entry["extra_in"])
            not_in = entry["not_in"]
            lines.append(f"  {key}")
            lines.append(f"    extra in: {extra_in}")
            lines.append(f"    not in base: {not_in}")
        lines.append("")

    if results["different"]:
        lines.append("DIFFERENT VALUES:")
        for entry in results["different"]:
            key = entry["key"]
            lines.append(f"  {key}")
            for fname, val in entry["files"].items():
                lines.append(f"    {fname}: {val}")
        lines.append("")

    if results["ok"]:
        ok_count = len(results["ok"])
        lines.append(f"OK: {ok_count} variable(s) in sync across all files.")

    return "\n".join(lines)


def format_json(results, has_diff):
    """Format results as JSON."""
    output = {
        "in_sync": not has_diff,
        "files": results["files"],
        "missing": results["missing"],
        "extra": results["extra"],
        "different": results["different"],
        "ok": results["ok"],
    }
    return json.dumps(output, indent=2)


def main():
    parser = argparse.ArgumentParser(
        description="Compare .env files and show missing, extra, and different variables."
    )
    parser.add_argument(
        "files",
        nargs="+",
        help="Two or more .env files to compare",
    )
    parser.add_argument(
        "--format",
        choices=["text", "json"],
        default="text",
        dest="output_format",
        help="Output format (default: text)",
    )
    parser.add_argument(
        "--base",
        default=None,
        help="Use this file as the reference base for comparison",
    )
    parser.add_argument(
        "--values",
        action="store_true",
        default=False,
        help="Show actual values (masked by default for security)",
    )

    args = parser.parse_args()

    if len(args.files) < 2:
        print("Error: At least two files are required.", file=sys.stderr)
        sys.exit(2)

    # Validate base file is in the file list
    if args.base and args.base not in args.files:
        print(f"Error: Base file '{args.base}' must be one of the compared files.", file=sys.stderr)
        sys.exit(2)

    # Parse all files
    file_envs = []
    for filepath in args.files:
        env = parse_env_file(filepath)
        file_envs.append((filepath, env))

    # Compare
    results, has_diff = compare_envs(file_envs, base_file=args.base, show_values=args.values)

    # Output
    if args.output_format == "json":
        print(format_json(results, has_diff))
    else:
        print(format_text(results, has_diff))

    sys.exit(1 if has_diff else 0)


if __name__ == "__main__":
    main()
