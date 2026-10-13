require "colorize"
require "json"

# Renders a decoded token and derives human-readable timing information.
module Output
  # Tokens expiring within this window are reported as "expires soon".
  SOON_THRESHOLD = 5.minutes

  # Registered claims that hold a Unix timestamp, in display order.
  TIME_CLAIMS = %w(exp iat nbf)

  enum ExpStatus
    None
    Expired
    Soon
    Ok
  end

  # Classifies the `exp` claim relative to now, with a message for the
  # expired and expiring-soon cases.
  def self.expiry_status(payload) : {ExpStatus, String}
    exp = payload["exp"]?.try(&.as_i64?)
    return {ExpStatus::None, ""} unless exp

    delta = Time.unix(exp) - Time.utc

    if delta.total_seconds < 0
      {ExpStatus::Expired, "token expired #{human_delta(delta)} ago"}
    elsif delta <= SOON_THRESHOLD
      {ExpStatus::Soon, "token expires in #{human_delta(delta)}"}
    else
      {ExpStatus::Ok, ""}
    end
  end

  # Whether the header declares the unsecured `none` algorithm.
  def self.unsigned?(header) : Bool
    header["alg"]?.try(&.as_s?).try(&.downcase) == "none"
  end

  def self.print(header, payload, signature : Bytes)
    section("HEADER")
    puts payload_json(header)
    puts
    section("PAYLOAD")
    puts payload_json(payload)
    puts

    times = TIME_CLAIMS.compact_map { |key| time_line(payload, key) }
    unless times.empty?
      times.each { |line| puts line }
      puts
    end

    section("SIGNATURE")
    if signature.empty?
      puts "none (empty signature segment)"
    else
      puts "bytes: #{signature.size} (not verified)"
    end
  end

  def self.payload_json(payload) : String
    JSON::Any.new(payload).to_pretty_json
  end

  private def self.section(title : String)
    puts title.colorize(:cyan)
    puts ("─" * title.size).colorize(:cyan)
  end

  # Formats a span as its two most significant units, e.g. `3d 4h` or `12m 5s`.
  private def self.human_delta(span : Time::Span) : String
    seconds = span.total_seconds.abs.to_i64
    days, seconds = seconds.divmod(86_400)
    hours, seconds = seconds.divmod(3_600)
    mins, secs = seconds.divmod(60)

    if days > 0
      "#{days}d #{hours}h"
    elsif hours > 0
      "#{hours}h #{mins}m"
    elsif mins > 0
      "#{mins}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  # One line per present time claim: the UTC timestamp plus a relative
  # description whose wording depends on what the claim means.
  private def self.time_line(payload, key : String) : String?
    seconds = payload[key]?.try(&.as_i64?)
    return unless seconds

    ts = Time.unix(seconds)
    delta = ts - Time.utc
    past = delta.total_seconds < 0
    ago = human_delta(delta)

    rel =
      case key
      when "exp"
        past ? "expired #{ago} ago".colorize(:red).bold : "expires in #{ago}".colorize(:green)
      when "iat"
        past ? "issued #{ago} ago".colorize : "issued in #{ago}, clock skew?".colorize(:yellow)
      else # nbf
        past ? "valid since #{ago} ago".colorize : "not valid for another #{ago}".colorize(:yellow)
      end

    "#{key}: #{ts.to_s("%FT%TZ")} (#{rel})"
  end
end
