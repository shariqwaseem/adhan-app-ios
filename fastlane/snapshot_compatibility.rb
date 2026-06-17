require "rubygems"
require "snapshot"

if Gem::Version.new(Fastlane::VERSION) < Gem::Version.new("2.236.0")
  module SnapshotUDIDDestination
    def destination(devices)
      unless verify_devices_share_os(devices)
        UI.user_error!("All devices provided to snapshot should run the same operating system")
      end

      return ["-destination 'platform=macOS'"] if devices.first.to_s.start_with?("Mac")

      os = case devices.first.to_s
           when /^Apple TV/ then "tvOS"
           when /^Apple Watch/ then "watchOS"
           else "iOS"
           end
      os_version = Snapshot.config[:ios_version] || Snapshot::LatestOsVersion.version(os)

      destinations = devices.map do |device_name|
        device = find_device(device_name, os_version)
        UI.user_error!("No device found named '#{device_name}'") unless device
        "-destination 'platform=#{os} Simulator,id=#{device.udid}'"
      end

      [destinations.join(" ")]
    end
  end

  Snapshot::TestCommandGenerator.singleton_class.prepend(SnapshotUDIDDestination)
end

module SnapshotPermissionSetup
  def override_status_bar(device_type, arguments = nil)
    super

    device_udid = Snapshot::TestCommandGenerator.device_udid(device_type)
    return unless device_udid

    bundle_id = Snapshot.config[:app_identifier] || "com.shariq.adhanapp"
    FastlaneCore::Helper.backticks(
      "xcrun simctl privacy #{device_udid} grant location #{bundle_id} &> /dev/null"
    )
    FastlaneCore::Helper.backticks(
      "xcrun simctl privacy #{device_udid} grant location-always #{bundle_id} &> /dev/null"
    )
    appearance = Snapshot.config[:dark_mode] ? "dark" : "light"
    FastlaneCore::Helper.backticks(
      "xcrun simctl ui #{device_udid} appearance #{appearance} &> /dev/null"
    )
  end
end

Snapshot::SimulatorLauncherBase.prepend(SnapshotPermissionSetup)
