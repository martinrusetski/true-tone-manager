cask "true-tone-manager" do
  version "0.4.2"
  sha256 "5bc91299e62758bd1ad0574c063fc3f222adaca86af5277e09f51ddc6e0e16e0"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.4.2/TrueToneManager-v0.4.2.dmg"
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
