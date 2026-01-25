
require "colorize"
require "json"
require "time"


module Output

  enum ExpStatus
    None
    Expired
    Soon
    Ok
  end

  private def self.c(s : String)
    s.colorize(:cyan)
  end

  def self.expiry_status(payload) : Tuple(ExpStatus, String)
    return {ExpStatus::None, ""} unless payload.has_key?("exp")
    exp = payload["exp"].as_i64?
    return {ExpStatus::None, ""} unless exp

    now = Time.utc
    exp_ts = Time.unix(exp).to_utc
    delta = exp_ts - now

    if delta.total_seconds < 0
      {ExpStatus::Expired, "token is expired (#{human_delta(delta)}) ago"}
    elsif delta.total_seconds <= 300 # atleast 5 minutes left
      {ExpStatus::Soon, "token expires soon (in #{human_delta(delta)})"}
    else
      {ExpStatus::Ok, ""}
    end
  end

  def self.print(header, payload, signature)
    puts c("HEADER")
    puts c("──────")
    puts JSON::Any.new(header).to_pretty_json
    puts
    puts c("PAYLOAD")
    puts c("───────")
    puts JSON::Any.new(payload).to_pretty_json
    puts
    %w(exp iat nbf).each do |k|
      print_time(payload, k)
    end
    puts
    puts c("SIGNATURE")
    puts c("─────────")
    puts "bytes: #{signature.size} (not verified)"
  end

  def self.payload_json(payload) : String
    JSON::Any.new(payload).to_pretty_json
  end

  private def self.human_delta(span : Time::Span) : String
    seconds = span.total_seconds.abs.to_i

    days = seconds // 86_400
    seconds %= 86_400

    hours = seconds // 3_600
    seconds %= 3_600

    mins = seconds // 60
    secs = seconds % 60
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

  private def self.print_time(payload, key)
    return unless payload.has_key?(key)
    sec = payload[key].as_i64?
    return unless sec

    ts = Time.unix(sec).to_utc
    delta = ts - Time.utc

    rel =
      if delta.total_seconds < 0
        msg = "expired #{human_delta(delta)} ago"
        msg.colorize(:red).bold
      else
        msg = "in #{human_delta(delta)}"
        msg.colorize(:green)
      end

    puts "#{key}: #{ts.to_s("%FT%TZ")} (#{rel})"
  end
end
