cask "true-tone-manager" do
  version "0.1.0"
  sha256 "7d39d20f12a494251e8b9a8c49acd918cda3e86cf65c24432c872d9fe5a3359f"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.1.0/TrueToneManager-v0.1.0.dmg"
  name "TrueTone Manager"
  desc "Automatically toggle macOS True Tone per application"
  homepage "https://github.com/martinrusetski/true-tone-manager"

  app "TrueTone Manager.app"

  postflight do
    system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/TrueTone Manager.app"]
  end

  zap trash: [
    "~/Library/Application Support/TrueToneManager",
  ]
end
