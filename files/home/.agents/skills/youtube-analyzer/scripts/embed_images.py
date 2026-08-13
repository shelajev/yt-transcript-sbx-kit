#!/usr/bin/env python3
"""Embed images as base64 data URIs into an HTML template.

The template contains placeholders of the form __IMG_<token>__. Each is replaced
with a data URI built from the matching image. Keeping this in a script prevents
large base64 payloads from passing through model context.

Usage:
    embed_images.py <template.html> <output.html> token1=path1 [token2=path2 ...]
"""

from __future__ import annotations

import base64
import mimetypes
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 4:
        print(
            "Usage: embed_images.py <template.html> <output.html> "
            "token=path [token=path ...]",
            file=sys.stderr,
        )
        return 2

    template_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    try:
        document = template_path.read_text(encoding="utf-8")
        for pair in sys.argv[3:]:
            if "=" not in pair:
                print(f"ERROR: malformed token/path pair: {pair}", file=sys.stderr)
                return 2

            token, image_name = pair.split("=", 1)
            if not token:
                print("ERROR: image token cannot be empty", file=sys.stderr)
                return 2

            placeholder = f"__IMG_{token}__"
            if placeholder not in document:
                print(
                    f"ERROR: placeholder {placeholder} not found in template",
                    file=sys.stderr,
                )
                return 1

            image_path = Path(image_name)
            mime = mimetypes.guess_type(image_path.name)[0] or "image/jpeg"
            payload = base64.b64encode(image_path.read_bytes()).decode("ascii")
            document = document.replace(
                placeholder, f"data:{mime};base64,{payload}"
            )

        if "__IMG_" in document:
            print("ERROR: unresolved __IMG_ placeholder remains", file=sys.stderr)
            return 1

        output_path.write_text(document, encoding="utf-8")
    except OSError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"wrote {output_path} ({len(document)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
