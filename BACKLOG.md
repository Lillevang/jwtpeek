## Backlog

### In progress
- **Signature verification**
  - HS256
    - Secret via env (`JWTPEEK_HS256_SECRET`)
    - Optional `--secret` flag (explicit / insecure)
  - RS256 / ES256 via PEM public key
  - Clear verification result (`valid` / `invalid`)
  - Non-zero exit on verification failure when requested

### Next
- **Claim validation helpers**
  - `--expect-iss`
  - `--expect-aud`
  - Exit non-zero on mismatch (shell-friendly)

- **Keycloak-aware inspection**
  - Detect Keycloak tokens from claims
  - Highlight:
    - realm roles
    - client roles
    - service-account tokens

### Nice-to-have (later)
- **JWK / JWKS support**
  - Fetch via `iss` discovery
  - Verify against remote keys
  - Caching + timeouts

- **OAuth flow helpers**
  - Token exchange (RFC 8693)
  - Refresh token helper
  - Clipboard in → clipboard out

### Distribution
- **Packaging**
  - COPR (Fedora)
  - PPA or hosted apt repo (Debian/Ubuntu)

### Quality of life
- Structured output mode (`--json`)
- Exit codes for common states (expired, invalid, mismatch)

### Long-term / refactor
- Extract reusable shards
  - Clipboard utilities
  - JWT parsing / inspection
