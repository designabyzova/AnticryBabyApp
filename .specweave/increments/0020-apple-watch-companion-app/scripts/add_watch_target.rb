#!/usr/bin/env ruby
# Add Apple Watch target to BabyInCarApp Xcode project
require 'xcodeproj'

project_path = File.expand_path('../../../../BabyInCarApp/BabyInCarApp.xcodeproj', __dir__)
puts "🔍 Looking for project at: #{project_path}"
unless File.exist?(project_path)
  puts "❌ Error: Project not found at #{project_path}"
  exit 1
end
project = Xcodeproj::Project.open(project_path)

# Find main iOS target
main_target = project.targets.find { |t| t.name == 'BabyInCarApp' }
unless main_target
  puts "❌ Error: Could not find main BabyInCarApp target"
  exit 1
end

puts "✅ Found main target: #{main_target.name}"

# Check if watch target already exists
existing_watch_target = project.targets.find { |t| t.name == 'BabyInCarWatchApp' }
if existing_watch_target
  puts "⚠️  Watch target already exists, skipping creation"
  watch_target = existing_watch_target
else
  # Create watchOS App target
  watch_target = project.new_target(:watch2_app, 'BabyInCarWatchApp', :watchos, '9.0')
  puts "✅ Created watchOS target: #{watch_target.name}"

  # Configure bundle identifier
  watch_target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.anticry.babyincar.watchkitapp'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
    config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '9.0'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['ENABLE_PREVIEWS'] = 'YES'
    config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
    config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  end
  puts "✅ Configured bundle identifier: com.anticry.babyincar.watchkitapp"
end

# Add WatchConnectivity framework to both targets
[main_target, watch_target].each do |target|
  framework_exists = target.frameworks_build_phase.files.any? do |file|
    file.file_ref && file.file_ref.path == 'WatchConnectivity.framework'
  end

  unless framework_exists
    framework = project.frameworks_group.new_file('WatchConnectivity.framework')
    framework.source_tree = 'SDKROOT'
    target.frameworks_build_phase.add_file_reference(framework)
    puts "✅ Added WatchConnectivity.framework to #{target.name}"
  end
end

# Create Shared group if it doesn't exist
shared_group = project.main_group.groups.find { |g| g.name == 'Shared' }
unless shared_group
  shared_group = project.main_group.new_group('Shared', 'BabyInCarApp/Shared')
  puts "✅ Created Shared group"
end

# Add WatchModels.swift to Shared group
watch_models_path = 'BabyInCarApp/Shared/WatchModels.swift'
watch_models_file = shared_group.files.find { |f| f.path == 'WatchModels.swift' }
unless watch_models_file
  watch_models_file = shared_group.new_file(watch_models_path)
  puts "✅ Added WatchModels.swift to Shared group"
end

# Add WatchModels.swift to both targets
[main_target, watch_target].each do |target|
  unless target.source_build_phase.files.any? { |f| f.file_ref == watch_models_file }
    target.source_build_phase.add_file_reference(watch_models_file)
    puts "✅ Added WatchModels.swift to #{target.name} build phase"
  end
end

# Create BabyInCarWatchApp group
watch_app_group = project.main_group.groups.find { |g| g.name == 'BabyInCarWatchApp' }
unless watch_app_group
  watch_app_group = project.main_group.new_group('BabyInCarWatchApp', 'BabyInCarApp/BabyInCarWatchApp')
  puts "✅ Created BabyInCarWatchApp group"
end

# Add watchOS app files
watch_files = {
  'BabyInCarWatchApp.swift' => 'BabyInCarApp/BabyInCarWatchApp/BabyInCarWatchApp.swift',
}

# Create Services subgroup
services_group = watch_app_group.groups.find { |g| g.name == 'Services' }
unless services_group
  services_group = watch_app_group.new_group('Services', 'BabyInCarApp/BabyInCarWatchApp/Services')
  puts "✅ Created Services group under BabyInCarWatchApp"
end

services_files = {
  'WatchConnectivityManager.swift' => 'BabyInCarApp/BabyInCarWatchApp/Services/WatchConnectivityManager.swift',
  'WatchAudioPlayer.swift' => 'BabyInCarApp/BabyInCarWatchApp/Services/WatchAudioPlayer.swift',
  'WatchStorageManager.swift' => 'BabyInCarApp/BabyInCarWatchApp/Services/WatchStorageManager.swift',
}

# Create Views subgroup
views_group = watch_app_group.groups.find { |g| g.name == 'Views' }
unless views_group
  views_group = watch_app_group.new_group('Views', 'BabyInCarApp/BabyInCarWatchApp/Views')
  puts "✅ Created Views group under BabyInCarWatchApp"
end

views_files = {
  'ContentView.swift' => 'BabyInCarApp/BabyInCarWatchApp/Views/ContentView.swift',
  'NowPlayingView.swift' => 'BabyInCarApp/BabyInCarWatchApp/Views/NowPlayingView.swift',
  'FavoritesListView.swift' => 'BabyInCarApp/BabyInCarWatchApp/Views/FavoritesListView.swift',
  'CryAlertsView.swift' => 'BabyInCarApp/BabyInCarWatchApp/Views/CryAlertsView.swift',
  'SleepTimerView.swift' => 'BabyInCarApp/BabyInCarWatchApp/Views/SleepTimerView.swift',
  'WatchOnboardingView.swift' => 'BabyInCarApp/BabyInCarWatchApp/Views/WatchOnboardingView.swift',
}

# Add main watch app file
watch_files.each do |name, path|
  file_ref = watch_app_group.files.find { |f| f.path == name }
  unless file_ref
    file_ref = watch_app_group.new_file(path)
    puts "✅ Added #{name} to BabyInCarWatchApp group"
  end

  unless watch_target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
    watch_target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added #{name} to watch target build phase"
  end
end

# Add service files
services_files.each do |name, path|
  file_ref = services_group.files.find { |f| f.path == name }
  unless file_ref
    file_ref = services_group.new_file(path)
    puts "✅ Added #{name} to Services group"
  end

  unless watch_target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
    watch_target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added #{name} to watch target build phase"
  end
end

# Add view files
views_files.each do |name, path|
  file_ref = views_group.files.find { |f| f.path == name }
  unless file_ref
    file_ref = views_group.new_file(path)
    puts "✅ Added #{name} to Views group"
  end

  unless watch_target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
    watch_target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added #{name} to watch target build phase"
  end
end

# Add WatchSyncManager.swift to main iOS target
ios_services_group = project.main_group.groups.find { |g| g.name == 'BabyInCarApp' }
                           &.groups&.find { |g| g.name == 'Services' }

if ios_services_group
  watch_sync_path = 'BabyInCarApp/BabyInCarApp/Services/WatchSyncManager.swift'
  watch_sync_file = ios_services_group.files.find { |f| f.path == 'WatchSyncManager.swift' }

  unless watch_sync_file
    watch_sync_file = ios_services_group.new_file(watch_sync_path)
    puts "✅ Added WatchSyncManager.swift to iOS Services group"
  end

  unless main_target.source_build_phase.files.any? { |f| f.file_ref == watch_sync_file }
    main_target.source_build_phase.add_file_reference(watch_sync_file)
    puts "✅ Added WatchSyncManager.swift to iOS target build phase"
  end
end

# Save the project
project.save
puts "\n🎉 Successfully updated Xcode project!"
puts "\n📋 Next steps:"
puts "1. Open BabyInCarApp.xcodeproj in Xcode"
puts "2. Select BabyInCarWatchApp scheme from the scheme selector"
puts "3. Build the project (Cmd+B)"
puts "4. Deploy to a paired Apple Watch"
