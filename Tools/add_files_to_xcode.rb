#!/usr/bin/env ruby
# Tools/add_files_to_xcode.rb
#
# Adds Swift source files to the vkey Xcode target while keeping
# project.pbxproj diffs minimal. Usage:
#
#   ruby Tools/add_files_to_xcode.rb \
#     "vkey/Lexicon/Lexicon.swift:Lexicon" \
#     "vkey/Lexicon/EmbeddedLexiconData.swift:Lexicon" \
#     ...
#
# The argument format is "<path-relative-to-project>:<group-name>". The group is
# created under the main "vkey" group if missing. Files already registered are
# left alone (idempotent).
#
# License: GPL-3.0 (same as the rest of the project).

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../vkey.xcodeproj', __dir__)
TARGET_NAME = 'vkey'

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME } \
  or abort("Target #{TARGET_NAME} not found")

main_group = project.main_group['vkey'] \
  or abort("Cannot find 'vkey' group in project")

added = 0
skipped = 0

ARGV.each do |arg|
  path, group_name = arg.split(':', 2)
  abort("Bad arg #{arg}, expected path:group") unless path && group_name

  abs_path = File.expand_path("../#{path}", __dir__)
  unless File.exist?(abs_path)
    warn "skip (not found): #{path}"
    next
  end

  # Find or create the group within the "vkey" group.
  group = main_group[group_name]
  unless group
    group = main_group.new_group(group_name, group_name)
  end

  # Skip if already registered.
  basename = File.basename(path)
  if group.files.any? { |f| f.display_name == basename }
    skipped += 1
    next
  end

  file_ref = group.new_reference(abs_path)
  target.add_file_references([file_ref])
  added += 1
  puts "added: #{path}"
end

if added > 0
  project.save
  puts "Saved project. Added #{added}, skipped #{skipped}."
else
  puts "Nothing to do. Skipped #{skipped}."
end
