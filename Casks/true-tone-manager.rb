cask "true-tone-manager" do
  version "0.5.1"
  sha256 "e2fb22fedfad3cb6593f95a73fe1905ce1ace57257b0dca0d6bd4b5ce4bd43d7"

  url "https://github.com/martinrusetski/true-tone-manager/releases/download/v0.5.1/TrueToneManager-v0.5.1.dmg"
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
