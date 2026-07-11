cask "true-tone-manager" do
  version "0.4.1"
  sha256 "e39110d0e8fb9e92613ca0799144d1e4cd8d94c2e28da8756e1ac0c29f94dffe"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.4.1/TrueToneManager-v0.4.1.dmg"
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
