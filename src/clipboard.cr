# Minimal clipboard access through whichever system tool is installed.
#
# Tools are tried in order of preference; the first one found on `PATH` wins.
module Clipboard
  # `{command, arguments}` pairs for reading the clipboard.
  READERS = [
    {"pbpaste", [] of String},                    # macOS
    {"wl-paste", ["--no-newline"]},               # Wayland
    {"xclip", ["-selection", "clipboard", "-o"]}, # X11
    {"xsel", ["--clipboard", "--output"]},        # X11
  ]

  # `{command, arguments}` pairs for writing the clipboard.
  WRITERS = [
    {"pbcopy", [] of String},                     # macOS
    {"wl-copy", [] of String},                    # Wayland
    {"xclip", ["-selection", "clipboard", "-i"]}, # X11
    {"xsel", ["--clipboard", "--input"]},         # X11
  ]

  INSTALL_HINT = "Install wl-clipboard (Wayland) or xclip/xsel (X11); pbcopy/pbpaste are used on macOS."

  # Returns the clipboard contents, or an empty string when nothing is copied.
  def self.read : String
    cmd, args = find(READERS) || raise "No clipboard reader found. #{INSTALL_HINT}"

    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run(cmd, args, output: output, error: error)
    return output.to_s if status.success?

    # wl-paste and xclip exit non-zero when the clipboard is empty.
    message = error.to_s.strip
    return "" if message =~ /no selection|not available/i
    raise "Clipboard read failed (#{cmd}): #{message}"
  end

  # Replaces the clipboard contents with *value*.
  def self.write(value : String) : Nil
    cmd, args = find(WRITERS) || raise "No clipboard writer found. #{INSTALL_HINT}"

    # wl-copy, xclip and xsel fork and keep running to serve the selection, so
    # their stdout/stderr must not be captured: reading those pipes would block
    # until the background process exits.
    status = Process.run(
      cmd, args,
      input: IO::Memory.new(value),
      output: Process::Redirect::Close,
      error: Process::Redirect::Close,
    )
    raise "Clipboard write failed (#{cmd})" unless status.success?
  end

  private def self.find(tools : Array({String, Array(String)})) : {String, Array(String)}?
    tools.find { |(cmd, _)| Process.find_executable(cmd) }
  end
end
