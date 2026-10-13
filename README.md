# jwtpeek

**A tiny, offline JWT inspector for the terminal. Copy a token, run `jwtpeek`, done.**

[![Release](https://img.shields.io/github/v/release/Lillevang/jwtpeek?display_name=tag)](https://github.com/Lillevang/jwtpeek/releases/latest)
[![Crystal](https://img.shields.io/badge/built%20with-Crystal-000000?logo=crystal)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Pasting production tokens into a browser-based decoder is a bad habit. `jwtpeek`
reads the JWT straight from your clipboard, decodes it locally, prints the header
and payload as pretty JSON, and tells you in plain words whether the token is
still valid. No browser tab, no network calls, no ceremony.

```
$ jwtpeek
HEADER
──────
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "2024-key-1"
}

PAYLOAD
───────
{
  "iss": "https://auth.example.com/realms/demo",
  "sub": "8f1c2a7e-4b3d-4f0e-9c1a-5d2e6b7f8a90",
  "aud": "orders-api",
  "iat": 1791914730,
  "exp": 1791915630,
  "scope": "openid orders:read"
}

exp: 2026-10-13T18:20:30Z (expires in 2m 14s)
iat: 2026-10-13T18:05:30Z (issued 12m 46s ago)

SIGNATURE
─────────
bytes: 256 (not verified)

⚠ token expires in 2m 14s
```

## Features

- **Clipboard in, answer out.** Reads the clipboard by default; also takes a
  token as an argument or on stdin for scripts and SSH sessions.
- **Finds the token in noise.** Works on logs, `curl` commands, HTTP headers and
  JSON blobs. A `Bearer` token wins when several tokens are present.
- **Timing in human terms.** `exp`, `iat` and `nbf` are printed as UTC timestamps
  with a relative description, plus a loud warning when a token is expired,
  about to expire, or unsigned (`"alg": "none"`).
- **Optional write-back.** `--copy` puts the decoded payload JSON back on the
  clipboard.
- **Fully offline.** The only network access is the explicit `--check-update`.
- **One small binary.** Written in [Crystal](https://crystal-lang.org); starts
  instantly, no runtime or dependencies to install.
- Colored output on a TTY, plain text when piped. Honors `NO_COLOR` and `--no-color`.

## Installation

### Prebuilt binary

Every release ships binaries for Linux (x86_64) and macOS (Apple Silicon), each
with a `.sha256` next to it.

```bash
# Linux x86_64
curl -fsSL https://github.com/Lillevang/jwtpeek/releases/latest/download/jwtpeek-linux-amd64 -o jwtpeek

# macOS (Apple Silicon)
curl -fsSL https://github.com/Lillevang/jwtpeek/releases/latest/download/jwtpeek-darwin-arm64 -o jwtpeek

chmod +x jwtpeek
mv jwtpeek ~/.local/bin/   # or anywhere on your PATH
```

### From source

Requires [Crystal](https://crystal-lang.org/install/) 1.17 or newer.

```bash
git clone https://github.com/Lillevang/jwtpeek.git
cd jwtpeek
shards build --release      # produces bin/jwtpeek
mv bin/jwtpeek ~/.local/bin/
```

### Clipboard support

`jwtpeek` shells out to the clipboard tool your platform already has:

| Platform | Tools used                              |
| -------- | --------------------------------------- |
| macOS    | `pbpaste` / `pbcopy` (built in)         |
| Wayland  | `wl-paste` / `wl-copy` (`wl-clipboard`) |
| X11      | `xclip` or `xsel`                       |

Without any of these you can still pass the token as an argument or via `--stdin`.

## Usage

```
Usage: jwtpeek [options] [TEXT]

Finds the first JWT in the clipboard (or in TEXT / stdin), decodes it and
prints the header, payload and timing claims. Signatures are not verified.

Options:
    -c, --copy                       Copy the decoded payload JSON back to the clipboard
        --stdin                      Read input from stdin instead of the clipboard
        --no-color                   Disable colored output (NO_COLOR is also respected)
        --check-update               Check GitHub for a newer release
    -v, --version                    Show version
    -h, --help                       Show this help
```

### Examples

```bash
# Copy a token (or a whole curl command, log line, Authorization header...)
# then simply:
jwtpeek

# Decode and put the payload JSON back on the clipboard
jwtpeek --copy

# Inspect a token you have in a variable or a file
jwtpeek "$ACCESS_TOKEN"
jwtpeek --stdin < token.txt

# Pull the token out of a live response
curl -s https://auth.example.com/token -d ... | jwtpeek --stdin

# Pipe-friendly: colors are dropped automatically and warnings go to stderr
jwtpeek > decoded.txt
```

The exit code is `0` when a token was decoded, `1` on any error (no token found,
malformed token, clipboard unavailable) and `2` for invalid options.

## What it does and does not do

- Header and payload are base64url-decoded and parsed as JSON. Nothing is
  validated beyond that.
- **Signatures are not verified.** The signature section only reports how many
  bytes were present. Treat the output as "what does this token claim", not
  "is this token genuine".
- Tokens are detected by the `eyJ` prefix that every base64url-encoded JSON
  object starts with, so version numbers and IP addresses are never mistaken
  for tokens.
- There are no configuration files and nothing is ever written to disk.

## Development

Every check, build and publish step is a [Task](https://taskfile.dev) command in
`Taskfile.yml`, so what runs on a release runner is exactly what runs on a laptop.

```bash
task            # same as task verify
task verify     # format check, specs, debug build, smoke test
task test       # just the specs
task fmt        # format sources in place
task dist       # release build to dist/jwtpeek-<os>-<arch> plus sha256
```

### Releasing

```bash
task bump                 # 0.1.3 → 0.1.4 (TARGET=minor|major for the others)
git commit -am "Bump to 0.1.4"
task release              # verify, tag v0.1.4, push
```

Pushing the tag triggers `.github/workflows/release.yml`, a thin wrapper that
runs `task verify`, `task dist` and `task publish` on a Linux and a macOS runner
and attaches both binaries to the GitHub release. The workflow holds no logic of
its own: `task dist publish` cuts the same release from any machine with `gh`.

`release` refuses to run from a dirty tree, from a branch other than `main`, or
for a tag that already exists. The version lives in `src/version.cr` and is
mirrored in `shard.yml`; `bump` keeps the two in sync and `check-tag` makes sure
the pushed tag matches.

## Roadmap

Planned work lives in [BACKLOG.md](BACKLOG.md). Highlights:

- Signature verification (HS256 via secret, RS256 / ES256 via PEM public key)
- Claim assertions such as `--expect-iss` / `--expect-aud` with shell-friendly exit codes
- Keycloak-aware role highlighting
- Structured `--json` output

## License

[MIT](LICENSE) © [Jeppe Lillevang Salling](https://github.com/Lillevang)
