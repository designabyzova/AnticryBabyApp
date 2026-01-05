#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'BabyInCarApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find test target
test_target = project.targets.find { |t| t.name == 'BabyInCarAppTests' }
unless test_target
  puts "Test target not found!"
  exit 1
end

# Check if we already have the package
package_url = 'https://github.com/pointfreeco/swift-snapshot-testing.git'
existing_pkg = project.root_object.package_references.find { |pkg| pkg.repositoryURL == package_url }

if existing_pkg
  puts "Package already exists in project"
else
  # Add Swift Package Reference
  package_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  package_ref.repositoryURL = package_url
  package_ref.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => '1.15.0' }
  project.root_object.package_references << package_ref
  puts "Added package reference"
end

# Find or create SnapshotTesting product dependency
product_dep = nil
test_target.package_product_dependencies.each do |dep|
  if dep.product_name == 'SnapshotTesting'
    product_dep = dep
    break
  end
end

unless product_dep
  # Find the package reference
  pkg_ref = project.root_object.package_references.find { |pkg| pkg.repositoryURL == package_url }

  # Create product dependency
  product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dep.product_name = 'SnapshotTesting'
  product_dep.package = pkg_ref

  # Add to test target
  test_target.package_product_dependencies << product_dep
  puts "Added SnapshotTesting dependency to test target"
end

# Add to frameworks build phase if needed
frameworks_phase = test_target.build_phases.find { |phase| phase.is_a?(Xcodeproj::Project::Object::PBXFrameworksBuildPhase) }
if frameworks_phase
  puts "Frameworks build phase exists"
end

project.save
puts "Project saved successfully!"
