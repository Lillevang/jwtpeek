require "json"
require "base64"

module JWT
  TOKEN_RE = /[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/
  BEARER_RE = /(?:Authorization:\s*)?Bearer\s+(#{TOKEN_RE})/i

  record Extraction, token : String, total : Int32, bearer : Bool

  def self.extract(text : String) : Extraction
    tokens = text.scan(TOKEN_RE).map(&.[0])
    if bearer_match = text.match(BEARER_RE)
      return Extraction.new(bearer_match[1], tokens.size, true)
    end

    token = tokens.first?
    raise "No JWT found in clipboard" unless token

    Extraction.new(token, tokens.size, false)
  end

  def self.decode(token : String)
    parts = token.split('.')
    raise "Invalid JWT format" unless parts.size == 3
    header  = decode_json(parts[0])
    payload = decode_json(parts[1])
    sig     = decode_raw(parts[2])
    {header, payload, sig}
  end

  private def self.decode_json(seg : String) : Hash(String, JSON::Any)
    padded = seg + "=" * ((4 - seg.size % 4) % 4)
    raw = Base64.decode(padded)
    JSON.parse(String.new(raw)).as_h
  end

  private def self.decode_raw(seg : String) : Bytes
    padded = seg + "=" * ((4 - seg.size % 4) % 4)
    Base64.decode(padded)
  end

end
