# src/clipboard.cr
module Clipboard
  def self.read : String
    {% if flag?(:darwin) %}
      `pbpaste`
    {% elsif flag?(:linux) %}
      if system("which wl-paste > /dev/null")
        `wl-paste`
      elsif system("which xclip > /dev/null")
        `xclip -selection clipboard -o`
      elsif system("which xsel > /dev/null")
        `xsel --clipboard --output`
      else
        raise "No clipboard reader found"
      end
    {% else %}
      raise "Unsupported OS"
    {% end %}
  end

  private def self.has?(bin : String) : Bool
    Process.run("which", [bin],
      output: Process::Redirect::Close,
      error: Process::Redirect::Close
    ).success?
  end

  private def self.pipe_in(cmd : Array(String), value : String) : Nil
    err = IO::Memory.new
    status = Process.run(
      cmd[0],
      cmd[1..],
      input: IO::Memory.new(value),
      output: Process::Redirect::Close,
      error: err
    )
    unless status.success?
      raise "Clipboard write failed: #{cmd.join(" ")}: #{err.to_s.strip}"
    end
  end

  def self.write(value : String) : Nil
    # macOS
    if has?("pbcopy")
      pipe_in(["pbcopy"], value)
      return
    end

    # Wayland
    if has?("wl-copy")
      # wl-copy forks by default; in some setups it won't detach if stderr is open.
      status = Process.run(
        "wl-copy",
        [] of String,
        input: IO::Memory.new(value),
        output: Process::Redirect::Close,
        error: Process::Redirect::Close
      )
      raise "Clipboard write failed: wl-copy" unless status.success?
      return
    end

    # X11
    if has?("xclip")
      pipe_in(["xclip", "-selection", "clipboard", "-i", "-loops", "1"], value)
      return
    end
    if has?("xsel")
      pipe_in(["xsel", "--clipboard", "--input"], value)
      return
    end

    raise "No clipboard writer found. Install one of: pbcopy (macOS), wl-clipboard (Wayland), xclip/xsel (X11)."
  end
end
