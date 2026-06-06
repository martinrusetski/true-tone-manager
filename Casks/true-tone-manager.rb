cask "true-tone-manager" do
  version "0.1.1"
  sha256 "b4ed0a54bbb9d6382dfec43f25cfcdaa00bff584b64407627dfc85dd2806dec7"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.1.1/TrueToneManager-v0.1.1.dmg"
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
