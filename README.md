# jwtpeek

A tiny, no-nonsense, clipboard-based JWT inspector for the terminal.

`jwtpeek` reads a JWT from your clipboard, decodes the header and payload, and prints them in a clean, readable format.  
No browser tabs. No network calls. No ceremony.

---

## Features

- Decode JWT **header** and **payload**
- Works on text containing JWTs (logs, curl commands, headers, etc.)
- Clear expiry information (expired / expires soon)
- Optional clipboard write-back of payload JSON
- Colored output (TTY only)
- Works fully offline

---

## Installation

### From source

```bash
git clone https://github.com/Lillevang/jwtpeek.git
cd jwtpeek
crystal build src/jwtpeek.cr --release
```

This produces a `jwtpeek` binary in the current directory.
You can then move it somewhhere on your `PATH`:

```bash
mv jwtpeek ~/.local/bin
```

## Usage

1. Copy a JWT (or text containing one) to your clipboard
2. Run:

```bash
jwtpeek
```
Optional: copy the decoded payload JSON back to the clipboard:

```bash
jwtpeek --copy  
```
### Example output

```
HEADER
──────
{
  "alg": "HS256",
  "typ": "JWT"
}

PAYLOAD
───────
{
  "sub": "1234567890",
  "name": "John Doe",
  "admin": true,
  "iat": 1769379926
}

iat: 2026-01-25T22:25:26Z (in 23h 47m)

SIGNATURE
─────────
bytes: 32 (not verified)

⚠ token expires soon
✔ payload copied to clipboard

```

---

## Notes

- JWT signatures are not verified (yet)
- The tool is intended for inspection and debugging
- No configuration files
- No network access

## Roadmap (rough)

- Signature verification (HS256 / RS256 / ES256 / etc)

## License

MIT

---

Created by

Jeppe Lillevang Salling
https://github.com/Lillevang
