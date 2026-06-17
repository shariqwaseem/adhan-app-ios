devices([
  "iPhone 11 Pro Max"
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
override_status_bar_arguments("--time 15:30 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --operatorName '' --cellularBars 4 --batteryState charged --batteryLevel 100")
dark_mode(false)
skip_open_summary(true)
stop_after_first_error(true)
number_of_retries(1)
