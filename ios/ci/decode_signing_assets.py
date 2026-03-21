#!/usr/bin/env python3
"""
Decode base64 → binary for iOS CI signing assets.
Handles: BOM, line-wrapped base64, missing padding, accidental whitespace.

Usage:
  python3 decode_signing_assets.py p12  <out.p12>   [--file path.b64 | --env-var NAME]
  python3 decode_signing_assets.py profile <out.mobileprovision> [--file path.b64 | --env-var NAME]

If neither --file nor --env-var, checks default repo paths:
  ios/ci/certificate.p12.b64
  ios/ci/profile.mobileprovision.b64
"""
from __future__ import annotations

import argparse
import base64
import os
import re
import sys


def read_b64_source(raw: str) -> bytes:
    if raw.startswith("\ufeff"):
        raw = raw[1:]
    raw = raw.strip()
    if "-----BEGIN" in raw:
        print(
            "ERROR: Input looks like PEM text. "
            "You must base64-encode the binary .p12 file (or .mobileprovision), not a .cer/.pem.",
            file=sys.stderr,
        )
        sys.exit(1)
    compact = re.sub(r"\s+", "", raw)
    pad = (-len(compact)) % 4
    compact += "=" * pad
    try:
        return base64.b64decode(compact, validate=True)
    except Exception:
        return base64.b64decode(compact, validate=False)


def load_input(args: argparse.Namespace) -> str:
    if args.file:
        path = args.file
        if not os.path.isfile(path):
            print(f"ERROR: File not found: {path}", file=sys.stderr)
            sys.exit(1)
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    if args.env_var:
        v = os.environ.get(args.env_var, "")
        if not v.strip():
            print(
                f"ERROR: Environment variable {args.env_var} is empty "
                f"(set GitHub secret or use --file / commit ios/ci/*.b64).",
                file=sys.stderr,
            )
            sys.exit(1)
        return v
    # Default files in repo (private CI)
    default = args.default_file
    if default and os.path.isfile(default):
        with open(default, encoding="utf-8", errors="replace") as f:
            return f.read()
    print(
        f"ERROR: No signing input. Either:\n"
        f"  • Set GitHub secret and pass --env-var, or\n"
        f"  • Commit {default} in the repo.\n",
        file=sys.stderr,
    )
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="kind", required=True)

    p12 = sub.add_parser("p12")
    p12.add_argument("output", help="Output path, e.g. certificate.p12")
    p12.add_argument("--file", help="Path to .b64 file")
    p12.add_argument("--env-var", help="Environment variable holding base64 string")
    p12.add_argument(
        "--default-file",
        default="ios/ci/certificate.p12.b64",
        help=argparse.SUPPRESS,
    )

    prof = sub.add_parser("profile")
    prof.add_argument("output", help="Output path, e.g. profile.mobileprovision")
    prof.add_argument("--file", help="Path to .b64 file")
    prof.add_argument("--env-var", help="Environment variable holding base64 string")
    prof.add_argument(
        "--default-file",
        default="ios/ci/profile.mobileprovision.b64",
        help=argparse.SUPPRESS,
    )

    args = parser.parse_args()
    raw = load_input(args)
    data = read_b64_source(raw)

    if args.kind == "p12":
        if len(data) < 50 or data[0] != 0x30:
            print(
                "ERROR: Decoded blob is not a valid PKCS#12 (DER usually starts with 0x30). "
                "Re-encode the binary .p12 only:  base64 -i cert.p12 | tr -d '\\n' > ios/ci/certificate.p12.b64",
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        if len(data) < 200:
            print("ERROR: Decoded provisioning profile is too small.", file=sys.stderr)
            sys.exit(1)

    with open(args.output, "wb") as f:
        f.write(data)
    print(f"OK: wrote {args.output} ({len(data)} bytes)")


if __name__ == "__main__":
    main()
