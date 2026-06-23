cask "true-tone-manager" do
  version "0.2.0"
  sha256 "8cc10254e8c44f29873d03aca535d87c6bda94154aae343aacacadacd28fb374"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.2.0/TrueToneManager-v0.2.0.dmg"
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
