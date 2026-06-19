#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = File.join(ROOT, "Numi.xcodeproj")

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.build_configurations.each do |config|
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
  config.build_settings["DEVELOPMENT_TEAM"] = ""
end

app_target = project.new_target(:application, "Numi", :ios, "17.0")
ui_target = project.new_target(:ui_test_bundle, "NumiUITests", :ios, "17.0")
ui_target.add_dependency(app_target)

app_group = project.main_group.new_group("App")
app_sources = app_group.new_group("NumiApp")
ui_sources = app_group.new_group("NumiUITests")

["NumiApp.swift", "RootShellView.swift"].each do |name|
  ref = app_sources.new_file("App/NumiApp/#{name}")
  app_target.add_file_references([ref])
end

info_ref = app_sources.new_file("App/NumiApp/Info.plist")
app_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.local.Numi"
  config.build_settings["INFOPLIST_FILE"] = "App/NumiApp/Info.plist"
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
  config.build_settings["MARKETING_VERSION"] = "1.0"
  config.build_settings["CURRENT_PROJECT_VERSION"] = "1"
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = ""
end

ui_ref = ui_sources.new_file("App/NumiUITests/NumiUITests.swift")
ui_target.add_file_references([ui_ref])
ui_target.build_configurations.each do |config|
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.local.NumiUITests"
  config.build_settings["TEST_TARGET_NAME"] = "Numi"
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
end

package_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package_ref.relative_path = "."
project.root_object.package_references << package_ref

["NumiCore", "NumiPersistence", "NumiAppUI"].each do |product|
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.product_name = product
  dependency.package = package_ref
  app_target.package_product_dependencies << dependency

  framework = project.frameworks_group.new_product_ref_for_target(product, :framework)
  build_file = app_target.frameworks_build_phase.add_file_reference(framework)
  build_file.product_ref = dependency
end

project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.set_launch_target(app_target)
scheme.add_test_target(ui_target)
scheme.save_as(project.path, "Numi", true)
