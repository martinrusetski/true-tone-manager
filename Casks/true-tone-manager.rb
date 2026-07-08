cask "true-tone-manager" do
  version "0.3.0"
  sha256 "63423505ac6243ec75b3806502c7e97bbc42ad005f662af3d810760078c55f5c"

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
