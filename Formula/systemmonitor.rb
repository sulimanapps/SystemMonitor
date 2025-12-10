cask "systemmonitor" do
  version "2.0.2"
  sha256 :no_check  # Update this with actual SHA256

  url "https://github.com/sulimanapps/SystemMonitor/releases/download/v#{version}/SystemMonitor-v#{version}.zip"
  name "SystemMonitor Pro"
  desc "Free & open-source system monitor for macOS"
  homepage "https://github.com/sulimanapps/SystemMonitor"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "SystemMonitor.app"

  zap trash: [
    "~/Library/Application Support/SystemMonitor",
    "~/Library/Caches/com.sulimanapps.SystemMonitor",
    "~/Library/Preferences/com.sulimanapps.SystemMonitor.plist",
  ]
end

# Installation instructions:
#
# Option 1: Add as a custom tap (recommended)
# 1. Create a new GitHub repo: homebrew-systemmonitor
# 2. Add this file as Casks/systemmonitor.rb
# 3. Users install with:
#    brew tap sulimanapps/systemmonitor
#    brew install --cask systemmonitor
#
# Option 2: Submit to homebrew-cask (for more visibility)
# https://github.com/Homebrew/homebrew-cask/blob/master/CONTRIBUTING.md
