cask "true-tone-manager" do
  version "0.2.1"
  sha256 "196954a6af3fa5e7738c49ac60e53e47422488cf80bf8a366144d9e982f25392"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.2.1/TrueToneManager-v0.2.1.dmg"
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
