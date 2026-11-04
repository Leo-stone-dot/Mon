#!/bin/bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 || ! -f "$1" || ! -d "$2" ]]; then
    echo "usage: $0 APPCAST_XML APP_BUNDLE [SPARKLE_SIGN_UPDATE_OUTPUT]" >&2
    exit 64
fi

appcast_path=$1
app_path=$2
signature_output=${3:-}
info_plist=$app_path/Contents/Info.plist

version=$(plutil -extract CFBundleShortVersionString raw "$info_plist")
build=$(plutil -extract CFBundleVersion raw "$info_plist")
minimum_system_version=$(plutil -extract LSMinimumSystemVersion raw "$info_plist")

ruby -rrexml/document - "$appcast_path" "$version" "$build" "$minimum_system_version" "$signature_output" <<'RUBY'
require "rexml/document"

appcast_path, version, build, minimum_system_version, signature_output = ARGV

def local_name(node)
  node.name.to_s.split(":").last
end

def child(element, child_name)
  element.elements.find { |candidate| local_name(candidate) == child_name }
end

def text_child(element, child_name)
  child(element, child_name)&.text&.strip
end

def attr(element, attribute_name)
  return nil if element.nil?

  value = nil
  element.attributes.each_attribute do |attribute|
    names = [attribute.name, attribute.expanded_name].compact
    if names.include?(attribute_name) || names.any? { |name| name.split(":").last == attribute_name }
      value = attribute.value
      break
    end
  end
  value
end

def https_url?(url)
  url&.start_with?("https://")
end

expected_signature = nil
expected_length = nil
if signature_output && !signature_output.empty?
  signature_text = File.read(signature_output)
  expected_signature = signature_text[/sparkle:edSignature="([^"]+)"/, 1]
  expected_length = signature_text[/sparkle:length="([^"]+)"/, 1] || signature_text[/\blength="([^"]+)"/, 1]
  abort "missing sparkle:edSignature in #{signature_output}" unless expected_signature
  abort "missing sparkle:length in #{signature_output}" unless expected_length
end

document = REXML::Document.new(File.read(appcast_path))
items = []
document.elements.each("//item") { |item| items << item }
abort "appcast has no items: #{appcast_path}" if items.empty?

matching_items = items.select do |item|
  enclosure = child(item, "enclosure")
  enclosure_version = attr(enclosure, "version")
  short_version = attr(enclosure, "shortVersionString") || text_child(item, "shortVersionString")

  version_matches = short_version.nil? || short_version == version
  build_matches = enclosure_version.nil? || enclosure_version == build
  explicit_match = short_version == version || enclosure_version == build

  explicit_match && version_matches && build_matches
end

abort "no appcast item matches version #{version} (build #{build})" if matching_items.empty?
abort "multiple appcast items match version #{version} (build #{build})" if matching_items.length > 1

item = matching_items.first
enclosure = child(item, "enclosure")
abort "matching appcast item has no enclosure" unless enclosure

enclosure_url = attr(enclosure, "url")
abort "appcast enclosure URL must be HTTPS" unless https_url?(enclosure_url)

release_notes_url = text_child(item, "releaseNotesLink")
if release_notes_url && !https_url?(release_notes_url)
  abort "appcast releaseNotesLink must be HTTPS"
end

item_minimum_system_version =
  attr(enclosure, "minimumSystemVersion") ||
  text_child(item, "minimumSystemVersion")
abort "appcast item minimumSystemVersion must be #{minimum_system_version}; found #{item_minimum_system_version.inspect}" unless item_minimum_system_version == minimum_system_version

ed_signature = attr(enclosure, "edSignature")
abort "appcast item missing sparkle:edSignature" if ed_signature.nil? || ed_signature.empty?

length = attr(enclosure, "length")
sparkle_length = attr(enclosure, "length")
abort "appcast item missing length" if length.nil? || length.empty?

if expected_signature && ed_signature != expected_signature
  abort "appcast sparkle:edSignature does not match signed archive output"
end

if expected_length && sparkle_length != expected_length
  abort "appcast length does not match signed archive output"
end

puts "appcast gate: #{version} (#{build}) minimumSystemVersion=#{minimum_system_version} enclosure=#{enclosure_url}"
RUBY
