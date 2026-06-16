devices([
  "iPhone 11 Pro Max",
  "iPad Pro 13-inch (M4)"
])
ios_version("26.3.1")

languages([
  "en-US",
  "ar",
  "id",
  "tr"
])

scheme("AdhanAppScreenshots")
project("./AdhanApp.xcodeproj")
app_identifier("com.shariq.adhanapp")
output_directory("./fastlane/screenshots")
clear_previous_screenshots(true)
reinstall_app(true)
erase_simulator(true)
override_status_bar(true)
dark_mode(true)
skip_open_summary(true)
stop_after_first_error(true)
number_of_retries(1)
