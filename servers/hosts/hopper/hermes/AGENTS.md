# Workspace contract

This directory is the only ordinary working area.

- Preserve user inputs; write derivatives to a clear subdirectory such as
  `output/`.
- For a PDF, keep its source (`.md`, `.typ`, or `.docx`) beside the final file.
- Inspect page count and rendering before reporting success.
- Do not use network services, install packages, access parent directories, or
  modify system configuration unless the user specifically asks.
- Python work belongs in `.venv/`: use `.venv/bin/python` and
  `.venv/bin/pip`, never the immutable system interpreter.  The virtualenv is
  private to this workspace; keep project dependencies there when the user has
  authorized their installation.
- Node.js, npm, Java, Pandoc, Typst, and archive tools are already on PATH.
