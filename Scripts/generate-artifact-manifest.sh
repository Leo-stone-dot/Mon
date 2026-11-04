#!/bin/bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 || ! -d "$1" ]]; then
    echo "usage: $0 APP_BUNDLE OUTPUT_JSON [ARCHIVE]" >&2
    exit 64
fi

app_path=$1
output_json=$2
archive_path=${3:-}

if [[ -n "$archive_path" && ! -f "$archive_path" ]]; then
    echo "missing archive: $archive_path" >&2
    exit 1
fi

mkdir -p "$(dirname "$output_json")"

ruby -rjson -rdigest - "$app_path" "$output_json" "$archive_path" <<'RUBY'
app_path = ARGV.fetch(0)
output_json = ARGV.fetch(1)
archive_path = ARGV.fetch(2)

def capture(*command)
  output = IO.popen(command, &:read)
  raise "#{command.join(' ')} failed" unless $?.success?
  output.strip
end

info_plist = File.join(app_path, "Contents", "Info.plist")
package_resolved = "Mon.xcworkspace/xcshareddata/swiftpm/Package.resolved"
dependencies = JSON.parse(File.read(package_resolved)).fetch("pins").map do |pin|
  state = pin.fetch("state")
  {
    "identity" => pin.fetch("identity"),
    "location" => pin.fetch("location"),
    "revision" => state.fetch("revision"),
    "version" => state["version"]
  }
end.sort_by { |dependency| dependency.fetch("identity") }

mach_o_files = Dir.glob(File.join(app_path, "**", "*"), File::FNM_DOTMATCH)
  .select { |path| File.file?(path) && capture("file", path).include?("Mach-O") }
  .map do |path|
    {
      "path" => path.delete_prefix("#{app_path}/"),
      "architectures" => capture("lipo", "-archs", path).split
    }
  end

manifest = {
  "bundleIdentifier" => capture("plutil", "-extract", "CFBundleIdentifier", "raw", info_plist),
  "version" => capture("plutil", "-extract", "CFBundleShortVersionString", "raw", info_plist),
  "build" => capture("plutil", "-extract", "CFBundleVersion", "raw", info_plist),
  "minimumSystemVersion" => capture("plutil", "-extract", "LSMinimumSystemVersion", "raw", info_plist),
  "commit" => capture("git", "rev-parse", "HEAD"),
  "sourceStatus" => capture("git", "status", "--short"),
  "macOS" => capture("sw_vers"),
  "xcode" => capture("xcodebuild", "-version"),
  "sdkVersion" => capture("xcrun", "--sdk", "macosx", "--show-sdk-version"),
  "packageResolvedSHA256" => capture("shasum", "-a", "256", package_resolved).split.first,
  "dependencies" => dependencies,
  "machOFiles" => mach_o_files,
  "notarizationSubmissionID" => ENV["AMETHYST_NOTARIZATION_SUBMISSION_ID"]
}

if !archive_path.empty?
  manifest["archive"] = {
    "path" => archive_path,
    "bytes" => File.size(archive_path),
    "sha256" => Digest::SHA256.file(archive_path).hexdigest
  }
end

File.write(output_json, "#{JSON.pretty_generate(manifest)}\n")
RUBY

echo "wrote $output_json"
