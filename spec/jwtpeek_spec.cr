require "./spec_helper"


describe JWT do
  it "extracts a JWT token from text" do
    text = "prefix abc.def.ghi suffix"
    extraction = JWT.extract(text)

    extraction.token.should eq("abc.def.ghi")
    extraction.total.should eq(1)
    extraction.bearer.should be_false
  end

  it "raises when no JWT is present" do
    expect_raises(Exception, "No JWT found in clipboard") do
      JWT.extract("no token here")
    end
  end

  it "prefers a Bearer token when present" do
    text = "Authorization: Bearer aaa.bbb.ccc and also abc.def.ghi"
    extraction = JWT.extract(text)

    extraction.token.should eq("aaa.bbb.ccc")
    extraction.total.should eq(2)
    extraction.bearer.should be_true
  end

  it "prefers a Bearer token when present after another token" do
    text = "abc.def.ghi and also Authorization: Bearer aaa.bbb.ccc"
    extraction = JWT.extract(text)

    extraction.token.should eq("aaa.bbb.ccc")
    extraction.total.should eq(2)
    extraction.bearer.should be_true
  end


  it "decodes a JWT into header, payload, and signature bytes" do
    header_json = %({"alg":"HS256","typ":"JWT"})
    payload_json = %({"sub":"123","exp":1700000000})
    signature = "sig"

    token = [
      Base64.urlsafe_encode(header_json),
      Base64.urlsafe_encode(payload_json),
      Base64.urlsafe_encode(signature),
    ].join(".")

    header, payload, sig = JWT.decode(token)

    header["alg"].as_s.should eq("HS256")
    payload["sub"].as_s.should eq("123")
    payload["exp"].as_i64.should eq(1_700_000_000_i64)
    String.new(sig).should eq("sig")
  end

  it "raises on invalid JWT format" do
    expect_raises(Exception, "Invalid JWT format") do
      JWT.decode("a.b")
    end
  end
end

describe Output do
  it "returns None when exp is missing" do
    payload = {"sub" => JSON::Any.new("123")}
    status, message = Output.expiry_status(payload)
    status.should eq(Output::ExpStatus::None)
    message.should eq("")
  end

  it "returns None when exp is not an integer" do
    payload = {"exp" => JSON::Any.new("nope")}
    status, message = Output.expiry_status(payload)
    status.should eq(Output::ExpStatus::None)
    message.should eq("")
  end

  it "returns Expired when exp is in the past" do
    past = (Time.utc - 10.seconds).to_unix
    payload = {"exp" => JSON::Any.new(past)}
    status, message = Output.expiry_status(payload)
    status.should eq(Output::ExpStatus::Expired)
    message.should contain("token is expired")
  end

  it "returns Soon when exp is within five minutes" do
    soon = (Time.utc + 60.seconds).to_unix
    payload = {"exp" => JSON::Any.new(soon)}
    status, message = Output.expiry_status(payload)
    status.should eq(Output::ExpStatus::Soon)
    message.should contain("token expires soon")
  end

it "returns Ok when exp is sufficiently in the future" do
    future = (Time.utc + 10.minutes).to_unix
    payload = {"exp" => JSON::Any.new(future)}
    status, message = Output.expiry_status(payload)
    status.should eq(Output::ExpStatus::Ok)
    message.should eq("")
  end
end
