#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'BabyInCarApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find main target
main_target = project.targets.find { |t| t.name == 'BabyInCarApp' }
unless main_target
  puts "Main target not found!"
  exit 1
end

# Files to add
files_to_add = [
  { path: 'BabyInCarApp/Services/MemoryMonitor.swift', group_path: 'BabyInCarApp/Services' },
  { path: 'BabyInCarApp/Views/DebugMemoryOverlay.swift', group_path: 'BabyInCarApp/Views' },
  { path: 'BabyInCarApp/Views/MemoryCleanupToast.swift', group_path: 'BabyInCarApp/Views' },
]

files_to_add.each do |file_info|
  file_path = file_info[:path]
  group_path = file_info[:group_path]

  # Check if file exists
  unless File.exist?(file_path)
    puts "File not found: #{file_path}, skipping..."
    next
  end

  # Navigate to the group
  group = project.main_group
  group_path.split('/').each do |part|
    subgroup = group.find_subpath(part, false)
    unless subgroup
      puts "Creating group: #{part}"
      subgroup = group.new_group(part, part)
    end
    group = subgroup
  end

  # Check if file already exists in project
  file_name = File.basename(file_path)
  existing_file = group.files.find { |f| f.path == file_name }

  if existing_file
    puts "File already exists in project: #{file_name}"
    next
  end

  # Add the file
  file_ref = group.new_file(file_name)
  main_target.add_file_references([file_ref])
  puts "Added: #{file_path}"
end

project.save
puts "Project saved!"
