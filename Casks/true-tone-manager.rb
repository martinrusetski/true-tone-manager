cask "true-tone-manager" do
  version "0.1.2"
  sha256 "c20b27c318ea8ac4a50779afdc1a842df021192b0b9e4d83ec03dc24dda0db2c"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.1.2/TrueToneManager-v0.1.2.dmg"
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
