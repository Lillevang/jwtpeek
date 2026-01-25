require "json"
require "base64"
require "openssl"

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

  def self.verify_hs256(token : String, secret : String) : Bool
    signing_input, signature = signing_input_and_signature(token)
    expected = OpenSSL::HMAC.digest(:sha256, secret, signing_input)
    secure_compare(signature, expected)
  end

  def self.verify_pem(token : String, pem : String, alg : String) : Bool
    signing_input, signature = signing_input_and_signature(token)
    key = OpenSSL::PKey.read(pem)
    digest = OpenSSL::Digest.new("SHA256")

    case alg
    when "RS256"
      key.verify(digest, signature, signing_input)
    when "ES256"
      der_signature = ecdsa_raw_to_der(signature)
      key.verify(digest, der_signature, signing_input)
    else
      raise "Unsupported algorithm: #{alg}"
    end
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

  private def self.signing_input_and_signature(token : String) : Tuple(String, Bytes)
    parts = token.split('.')
    raise "Invalid JWT format" unless parts.size == 3

    signing_input = "#{parts[0]}.#{parts[1]}"
    signature = decode_raw(parts[2])

    {signing_input, signature}
  end

  private def self.secure_compare(a : Bytes, b : Bytes) : Bool
    return false unless a.size == b.size

    result = 0
    a.size.times do |i|
      result |= a[i] ^ b[i]
    end

    result == 0
  end

  private def self.ecdsa_raw_to_der(signature : Bytes) : Bytes
    raise "Invalid ECDSA signature length" unless signature.size == 64

    r = signature[0, 32]
    s = signature[32, 32]

    r = trim_integer(r)
    s = trim_integer(s)

    total_length = 2 + r.size + 2 + s.size
    der = Bytes.new(2 + total_length)
    idx = 0
    der[idx] = 0x30_u8
    idx += 1
    der[idx] = total_length.to_u8
    idx += 1
    der[idx] = 0x02_u8
    idx += 1
    der[idx] = r.size.to_u8
    idx += 1
    r.each do |byte|
      der[idx] = byte
      idx += 1
    end
    der[idx] = 0x02_u8
    idx += 1
    der[idx] = s.size.to_u8
    idx += 1
    s.each do |byte|
      der[idx] = byte
      idx += 1
    end

    der
  end

  private def self.trim_integer(raw : Bytes) : Bytes
    idx = 0
    while idx < raw.size - 1 && raw[idx] == 0
      idx += 1
    end
    trimmed = raw[idx, raw.size - idx]
    if trimmed[0] & 0x80_u8 != 0
      prefixed = Bytes.new(trimmed.size + 1)
      prefixed[0] = 0
      trimmed.each_with_index do |byte, i|
        prefixed[i + 1] = byte
      end
      prefixed
    else
      trimmed
    end
  end

end
