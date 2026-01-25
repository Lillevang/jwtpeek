require "colorize"
require "option_parser"

require "./clipboard"
require "./jwt"
require "./output"
require "./update_checker"
require "./version"

copy = false
check_update = false
show_version = false

OptionParser.parse do |parser|
  parser.banner = "Usage: jwtpeek [options]"

  parser.on("--copy", "Copy payload JSON to clipboard") do
    copy = true
  end

  parser.on("--version", "Show version") do
    show_version = true
  end

  parser.on("--check-update", "Check for updates") do
    check_update = true
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

if show_version
  puts Jwtpeek::VERSION
  exit
end

if check_update
  begin
    result = Jwtpeek::UpdateChecker.check
    msg = Jwtpeek::UpdateChecker.message(result)

    if result.comparison < 0
      puts msg.colorize(:yellow)
    else
      puts msg.colorize(:green)
    end
  rescue ex
    STDERR.puts "Unable to check for updates: #{ex.message}".colorize(:red).bold
    exit 1
  end
  exit
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
