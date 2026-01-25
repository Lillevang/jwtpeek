require "option_parser"

require "./clipboard"
require "./jwt"
require "./output"

copy = false

OptionParser.parse do |parser|
  parser.banner = "Usage: jwtpeek [options]"

  parser.on("--copy", "Copy payload JSON to clipboard") do
    copy = true
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

def warn_line(msg : String)
  STDERR.puts
  STDERR.puts(msg.colorize(:yellow).bold)
end

def ok_line(msg : String)
  STDERR.puts
  STDERR.puts(msg.colorize(:green).bold)
end


begin

  text = Clipboard.read
  raise "Clipboard is empty" if text.strip.empty?

  extraction = JWT.extract(text)
  if extraction.total > 1 && !extraction.bearer
    STDERR.puts("ℹ found #{extraction.total} JWTs in clipboard, using first")
  elsif extraction.total > 1 && extraction.bearer
    STDERR.puts("ℹ found #{extraction.total} JWTs in clipboard, using Bearer token")
  end

  header, payload, signature = JWT.decode(extraction.token)

  Output.print(header, payload, signature)

  status, msg = Output.expiry_status(payload)
  case status
  when Output::ExpStatus::Expired
    warn_line("⚠  #{msg}")
  when Output::ExpStatus::Soon
    warn_line("⚠ #{msg}")
  end

  if copy
    Clipboard.write(Output.payload_json(payload))
    ok_line("✔ payload copied to clipboard")
  end

rescue ex
  STDERR.puts("jwtpeek: #{ex.message}".colorize(:red).bold)
  exit 1
end
