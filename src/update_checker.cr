require "colorize"
require "http/client"
require "json"

require "./version"

module Jwtpeek
  module UpdateChecker
    API_URL = "https://api.github.com/repos/Lillevang/jwtpeek/releases/latest"

    record Result, latest : String, comparison : Int32

    def self.check(client = HTTP::Client) : Result
      headers = HTTP::Headers{
        "User-Agent" => "jwtpeek/#{VERSION}",
        "Accept"     => "application/vnd.github+json"
      }

      response = client.get(API_URL, headers: headers)
      unless response.status.success?
        raise "GitHub API returned #{response.status_code}"
      end

      data = JSON.parse(response.body)
      tag = data["tag_name"].as_s
      latest = normalize_version(tag)
      Result.new(latest, compare_versions(VERSION, latest))
    end

    def self.message(result : Result)
      if result.comparison < 0
        puts "Update available: v#{result.latest} (current v#{VERSION}).".colorize(:yellow)
      else
        puts "You're up to date (v#{VERSION}).".colorize(:green)
      end
    end

    def self.normalize_version(tag : String) : String
      tag.starts_with?("v") ? tag[1..-1] : tag
    end

    def self.compare_versions(current : String, latest : String) : Int32
      current_parts = current.split('.').map(&.to_i)
      latest_parts = latest.split('.').map(&.to_i)
      max = {current_parts.size, latest_parts.size}.max

      current_parts = current_parts + Array.new(max - current_parts.size, 0)
      latest_parts = latest_parts + Array.new(max - latest_parts.size, 0)

      current_parts.zip(latest_parts).each do |current_part, latest_part|
        next if current_part == latest_part
        return current_part < latest_part ? -1 : 1
      end

      0
    end
  end
end
