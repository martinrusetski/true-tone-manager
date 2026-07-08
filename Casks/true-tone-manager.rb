cask "true-tone-manager" do
  version "0.3.0"
  sha256 "efec134987e6a709231b572185177444c1c8b14fc17fec21ed725fd373026f5a"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.3.0/TrueToneManager-v0.3.0.dmg"
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
