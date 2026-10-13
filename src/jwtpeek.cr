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
use_stdin = false
text_arg = nil

OptionParser.parse do |parser|
  parser.banner = <<-BANNER
    Usage: jwtpeek [options] [TEXT]

    Finds the first JWT in the clipboard (or in TEXT / stdin), decodes it and
    prints the header, payload and timing claims. Signatures are not verified.

    Options:
    BANNER

  parser.on("-c", "--copy", "Copy the decoded payload JSON back to the clipboard") { copy = true }
  parser.on("--stdin", "Read input from stdin instead of the clipboard") { use_stdin = true }
  parser.on("--no-color", "Disable colored output (NO_COLOR is also respected)") { Colorize.enabled = false }
  parser.on("--check-update", "Check GitHub for a newer release") { check_update = true }
  parser.on("-v", "--version", "Show version") { show_version = true }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end

  parser.unknown_args do |args, after_dashes|
    rest = args + after_dashes
    text_arg = rest.join(" ") unless rest.empty?
  end

  parser.invalid_option do |flag|
    STDERR.puts "jwtpeek: unknown option #{flag}"
    STDERR.puts parser
    exit 2
  end
end

if show_version
  puts Jwtpeek::VERSION
  exit
end

if check_update
  begin
    result = Jwtpeek::UpdateChecker.check
    message = Jwtpeek::UpdateChecker.message(result)
    puts message.colorize(result.comparison < 0 ? :yellow : :green)
  rescue ex
    STDERR.puts "jwtpeek: unable to check for updates: #{ex.message}".colorize(:red).bold
    exit 1
  end
  exit
end

def note(message : String)
  STDERR.puts "ℹ #{message}"
end

def warn(message : String)
  STDERR.puts
  STDERR.puts "⚠ #{message}".colorize(:yellow).bold
end

def ok(message : String)
  STDERR.puts
  STDERR.puts "✔ #{message}".colorize(:green).bold
end

begin
  text, source =
    if arg = text_arg
      {arg, "argument"}
    elsif use_stdin
      {STDIN.gets_to_end, "stdin"}
    else
      {Clipboard.read, "clipboard"}
    end
  raise "#{source.capitalize} is empty" if text.strip.empty?

  extraction = JWT.extract(text, source)
  if extraction.total > 1
    chosen = extraction.bearer ? "the Bearer token" : "the first one"
    note "found #{extraction.total} JWTs in #{source}, using #{chosen}"
  end

  header, payload, signature = JWT.decode(extraction.token)
  Output.print(header, payload, signature)

  warn "alg is \"none\": this token is unsigned" if Output.unsigned?(header)

  status, message = Output.expiry_status(payload)
  warn message if status.expired? || status.soon?

  if copy
    Clipboard.write(Output.payload_json(payload))
    ok "payload copied to clipboard"
  end
rescue ex
  STDERR.puts "jwtpeek: #{ex.message}".colorize(:red).bold
  exit 1
end
