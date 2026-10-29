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

# project.pbxproj carries UTF-8 (Vietnamese group and file names). Ruby picks
# its default external encoding from the locale, so with LANG unset — a bare
# shell, cron, most CI runners — it reads as US-ASCII and xcodeproj dies with
# "invalid byte sequence in US-ASCII" before doing anything. Don't make the
# caller's environment decide this.
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

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

  # "Already registered" has to mean "the target compiles this file", not "some
  # group holds a reference with this name". The old check looked only at
  # `group.files`, which gets both cases wrong: a file already referenced from a
  # DIFFERENT group was added a second time (duplicate reference → "Multiple
  # commands produce" at build time), and a file sitting in the right group but
  # never wired into the target was reported as skipped and silently never
  # compiled. Compare resolved paths so a rename of the group can't fool it.
  in_target = target.source_build_phase.files_references.any? do |ref|
    ref.real_path.to_s == abs_path
  end
  if in_target
    skipped += 1
    next
  end

  # The file may still have a reference somewhere without being in the target —
  # reuse it rather than creating a second one pointing at the same path.
  file_ref = project.files.find { |f| f.real_path.to_s == abs_path }
  file_ref ||= group.new_reference(abs_path)
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
