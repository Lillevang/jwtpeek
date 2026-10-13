require "json"
require "base64"

# Finds and decodes JSON Web Tokens inside arbitrary text.
#
# Only the compact serialization (`header.payload.signature`) is handled and
# signatures are never verified: the segments are base64url-decoded, nothing more.
module JWT
  # The header and payload are JSON objects, so their base64url encodings
  # always start with `eyJ` (the encoding of `{"`). Requiring that prefix keeps
  # version numbers, IP addresses and similar dotted strings from being taken
  # for tokens. The signature segment may be empty (`"alg": "none"`).
  TOKEN_RE = /eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*/

  # A token preceded by a `Bearer` scheme, as found in HTTP headers and curl commands.
  BEARER_RE = /Bearer\s+(#{TOKEN_RE})/i

  # The token picked from a piece of text, how many tokens the text contained
  # and whether the chosen one was a `Bearer` token.
  record Extraction, token : String, total : Int32, bearer : Bool

  # Picks the JWT to inspect from *text*.
  #
  # A `Bearer` token wins over any other token; otherwise the first match is used.
  def self.extract(text : String, source : String = "input") : Extraction
    tokens = text.scan(TOKEN_RE).map(&.[0])

    if bearer = text.match(BEARER_RE)
      return Extraction.new(bearer[1], tokens.size, true)
    end

    token = tokens.first? || raise "No JWT found in #{source}"
    Extraction.new(token, tokens.size, false)
  end

  # Splits *token* into its decoded header, payload and raw signature bytes.
  def self.decode(token : String) : {Hash(String, JSON::Any), Hash(String, JSON::Any), Bytes}
    parts = token.split('.')
    unless parts.size == 3
      raise "Invalid JWT format: expected 3 dot-separated segments, got #{parts.size}"
    end

    {
      decode_json(parts[0], "header"),
      decode_json(parts[1], "payload"),
      decode_segment(parts[2]),
    }
  end

  private def self.decode_json(segment : String, name : String) : Hash(String, JSON::Any)
    JSON.parse(String.new(decode_segment(segment))).as_h
  rescue Base64::Error | JSON::ParseException | TypeCastError
    raise "Invalid JWT: #{name} is not a base64url-encoded JSON object"
  end

  private def self.decode_segment(segment : String) : Bytes
    padding = "=" * ((4 - segment.size % 4) % 4)
    Base64.decode(segment + padding)
  end
end
