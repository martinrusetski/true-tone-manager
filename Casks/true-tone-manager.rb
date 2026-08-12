cask "true-tone-manager" do
  version "0.5.2"
  sha256 "e133583c0d32151fa03de91ef231bd804c98a0962a44065679777dd89ca5db19"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.5.2/TrueToneManager-v0.5.2.dmg"
  name "TrueTone Manager"
  desc "Automatically toggle True Tone per application"
  homepage "https://github.com/martinrusetski/true-tone-manager"

  depends_on macos: :ventura

  app "TrueTone Manager.app"

  postflight do
    system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/TrueTone Manager.app"]
  end

  zap trash: "~/Library/Application Support/TrueToneManager"
end
