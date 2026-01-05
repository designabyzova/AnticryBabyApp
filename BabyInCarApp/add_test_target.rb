#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'BabyInCarApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Check if test target already exists
if project.targets.find { |t| t.name == 'BabyInCarAppTests' }
  puts "Test target already exists!"
  exit 0
end

# Find the main target
main_target = project.targets.find { |t| t.name == 'BabyInCarApp' }
unless main_target
  puts "Main target not found!"
  exit 1
end

# Create the unit test target
test_target = project.new_target(
  :unit_test_bundle,
  'BabyInCarAppTests',
  :ios,
  '16.0'
)

# Set test host to main app
test_target.build_configurations.each do |config|
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/BabyInCarApp.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/BabyInCarApp'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.anticry.babyincar.tests'
  config.build_settings['INFOPLIST_FILE'] = ''
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = main_target.build_configurations.first.build_settings['DEVELOPMENT_TEAM']
end

# Add dependency on main target
test_target.add_dependency(main_target)

# Create or find the tests group
tests_group = project.main_group.find_subpath('BabyInCarAppTests', true)
tests_group.set_source_tree('SOURCE_ROOT')
tests_group.set_path('BabyInCarAppTests')

# Add all test files
test_files_to_add = Dir.glob('BabyInCarAppTests/**/*.swift')
test_files_to_add.each do |file_path|
  relative_path = file_path.sub('BabyInCarAppTests/', '')

  # Create subgroups as needed
  path_parts = relative_path.split('/')
  current_group = tests_group

  path_parts[0..-2].each do |part|
    subgroup = current_group.find_subpath(part, false)
    unless subgroup
      subgroup = current_group.new_group(part, part)
    end
    current_group = subgroup
  end

  # Add the file if not already present
  file_name = path_parts.last
  unless current_group.find_file_by_path(file_name)
    file_ref = current_group.new_file(file_name)
    test_target.add_file_references([file_ref])
  end
end

# Save the project
project.save

puts "Test target added successfully!"
puts "Test files added: #{test_files_to_add.count}"
