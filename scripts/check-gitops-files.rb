#!/usr/bin/env ruby
require "yaml"

files = IO.popen(["git", "ls-files", "-z"], &:read).split("\0")
errors = []

files.each do |path|
  next unless File.file?(path)

  if path.match?(%r{(?:^|/)(?:\.env(?:\..+)?|[^/]+\.(?:pem|key|p12|pfx))\z}i) &&
     !path.end_with?(".example")
    errors << "#{path}: sensitive file must not be tracked"
  end

  content = File.read(path)
  next unless content.valid_encoding? && !content.include?("\0")

  if content.match?(/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/) ||
     content.match?(/\bAKIA[0-9A-Z]{16}\b/)
    errors << "#{path}: possible private key or AWS access key"
  end

  next unless path.end_with?(".yaml", ".yml")
  next if path.start_with?("charts/application/templates/")

  begin
    YAML.load_stream(content).each do |document|
      if document.is_a?(Hash) && document["kind"] == "Secret"
        errors << "#{path}: Kubernetes Secret manifest must not contain values in Git"
      end
    end
  rescue Psych::Exception => error
    errors << "#{path}: invalid YAML (#{error.message.lines.first.strip})"
  end
end

if errors.any?
  warn errors.join("\n")
  exit 1
end

puts "Tracked YAML and sensitive-file checks passed"
