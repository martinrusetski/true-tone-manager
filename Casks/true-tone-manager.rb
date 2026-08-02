cask "true-tone-manager" do
  version "0.5.0"
  sha256 "9f894d6b4f9683a7b2c376b5765205f5b18e6b915e7a219c8ceef05d686d6e1a"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.5.0/TrueToneManager-v0.5.0.dmg"
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
