require "./spec_helper"

# Builds a compact-serialized token from JSON strings; the signature is raw text.
private def make_token(header : String, payload : String, signature : String = "sig") : String
  [
    Base64.urlsafe_encode(header, padding: false),
    Base64.urlsafe_encode(payload, padding: false),
    Base64.urlsafe_encode(signature, padding: false),
  ].join(".")
end

private def payload_with(key : String, value) : Hash(String, JSON::Any)
  {key => JSON::Any.new(value)}
end

TOKEN_A = make_token(%({"alg":"HS256","typ":"JWT"}), %({"sub":"a"}))
TOKEN_B = make_token(%({"alg":"RS256","typ":"JWT"}), %({"sub":"b"}))

describe JWT do
  describe ".extract" do
    it "extracts a JWT from surrounding text" do
      extraction = JWT.extract("token=#{TOKEN_A}; path=/")

      extraction.token.should eq(TOKEN_A)
      extraction.total.should eq(1)
      extraction.bearer.should be_false
    end

    it "raises when no JWT is present" do
      expect_raises(Exception, "No JWT found in clipboard") do
        JWT.extract("no token here", "clipboard")
      end
    end

    it "ignores dotted strings that are not JWTs" do
      expect_raises(Exception, "No JWT found") do
        JWT.extract("crystal 1.19.1 on 10.0.0.1 with abc.def.ghi")
      end
    end

    it "prefers a Bearer token when present" do
      extraction = JWT.extract("Authorization: Bearer #{TOKEN_B} and also #{TOKEN_A}")

      extraction.token.should eq(TOKEN_B)
      extraction.total.should eq(2)
      extraction.bearer.should be_true
    end

    it "prefers a Bearer token even when another token comes first" do
      extraction = JWT.extract("#{TOKEN_A} and curl -H 'Authorization: Bearer #{TOKEN_B}'")

      extraction.token.should eq(TOKEN_B)
      extraction.total.should eq(2)
      extraction.bearer.should be_true
    end

    it "accepts an unsigned token with an empty signature segment" do
      token = make_token(%({"alg":"none"}), %({"sub":"x"}), "")
      token.should end_with(".")

      JWT.extract("#{token} trailing").token.should eq(token)
    end
  end

  describe ".decode" do
    it "decodes a JWT into header, payload, and signature bytes" do
      token = make_token(%({"alg":"HS256","typ":"JWT"}), %({"sub":"123","exp":1700000000}))

      header, payload, sig = JWT.decode(token)

      header["alg"].as_s.should eq("HS256")
      payload["sub"].as_s.should eq("123")
      payload["exp"].as_i64.should eq(1_700_000_000_i64)
      String.new(sig).should eq("sig")
    end

    it "returns empty signature bytes for unsigned tokens" do
      _, _, sig = JWT.decode(make_token(%({"alg":"none"}), %({"sub":"x"}), ""))
      sig.should be_empty
    end

    it "raises on the wrong number of segments" do
      expect_raises(Exception, "Invalid JWT format") do
        JWT.decode("a.b")
      end
    end

    it "raises a readable error when a segment is not JSON" do
      bad = Base64.urlsafe_encode("not json", padding: false)
      expect_raises(Exception, "Invalid JWT: payload is not a base64url-encoded JSON object") do
        JWT.decode("#{TOKEN_A.split('.')[0]}.#{bad}.sig")
      end
    end

    it "raises a readable error when a segment is not base64" do
      expect_raises(Exception, "Invalid JWT: header is not a base64url-encoded JSON object") do
        JWT.decode("eyJ%%.eyJ.sig")
      end
    end
  end
end

describe Output do
  describe ".expiry_status" do
    it "returns None when exp is missing" do
      status, message = Output.expiry_status(payload_with("sub", "123"))
      status.should eq(Output::ExpStatus::None)
      message.should eq("")
    end

    it "returns None when exp is not an integer" do
      status, message = Output.expiry_status(payload_with("exp", "nope"))
      status.should eq(Output::ExpStatus::None)
      message.should eq("")
    end

    it "returns Expired when exp is in the past" do
      past = (Time.utc - 10.seconds).to_unix
      status, message = Output.expiry_status(payload_with("exp", past))
      status.should eq(Output::ExpStatus::Expired)
      message.should match(/^token expired \d+s ago$/)
    end

    it "returns Soon when exp is within five minutes" do
      soon = (Time.utc + 60.seconds).to_unix
      status, message = Output.expiry_status(payload_with("exp", soon))
      status.should eq(Output::ExpStatus::Soon)
      message.should match(/^token expires in \d+s$/)
    end

    it "returns Ok when exp is sufficiently in the future" do
      future = (Time.utc + 10.minutes).to_unix
      status, message = Output.expiry_status(payload_with("exp", future))
      status.should eq(Output::ExpStatus::Ok)
      message.should eq("")
    end
  end

  describe ".unsigned?" do
    it "detects the none algorithm case-insensitively" do
      Output.unsigned?(payload_with("alg", "none")).should be_true
      Output.unsigned?(payload_with("alg", "None")).should be_true
      Output.unsigned?(payload_with("alg", "HS256")).should be_false
      Output.unsigned?(payload_with("typ", "JWT")).should be_false
    end
  end
end

describe Jwtpeek::UpdateChecker do
  it "normalizes tag names with a leading v" do
    Jwtpeek::UpdateChecker.normalize_version("v0.1.2").should eq("0.1.2")
    Jwtpeek::UpdateChecker.normalize_version("0.1.2").should eq("0.1.2")
  end

  it "reports update available when a newer version exists" do
    result = Jwtpeek::UpdateChecker::Result.new("0.2.0", -1)
    Jwtpeek::UpdateChecker.message(result).should contain("Update available")
  end

  it "reports up to date when versions match" do
    result = Jwtpeek::UpdateChecker::Result.new(Jwtpeek::VERSION, 0)
    Jwtpeek::UpdateChecker.message(result).should contain("up to date")
  end

  it "compares semantic versions" do
    Jwtpeek::UpdateChecker.compare_versions("0.1.2", "0.1.3").should eq(-1)
    Jwtpeek::UpdateChecker.compare_versions("1.0.0", "0.9.9").should eq(1)
    Jwtpeek::UpdateChecker.compare_versions("0.1.2", "0.1.2").should eq(0)
    Jwtpeek::UpdateChecker.compare_versions("1.0", "1.0.0").should eq(0)
  end
end
