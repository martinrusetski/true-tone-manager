cask "true-tone-manager" do
  version "0.4.0"
  sha256 "356e54b70dca1846845819aebab3b570136ffccc38fb09d9e12cd6d00ad1dc89"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.4.0/TrueToneManager-v0.4.0.dmg"
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
