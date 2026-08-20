cask "rom-shortcut-maker" do
  version "0.1.0"
  sha256 "2025901f3732a2ca3d846b25b7f6cdb65479c6f8e5af17bd0e00d1de469d0a11"

  url "https://github.com/martinrusetski/rom-shortcut-maker/releases/download/v#{version}/RomShortcutMaker-v#{version}.dmg"
  name "Rom Shortcut Maker"
  desc "Generate native launchers for your ROMs from installed emulators"
  homepage "https://github.com/martinrusetski/rom-shortcut-maker"

  depends_on macos: :tahoe

  app "Rom Shortcut Maker.app"

  postflight do
    system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/Rom Shortcut Maker.app"]
  end

  zap trash: [
    "~/Library/Application Support/RomShortcutMaker",
    "~/Library/Caches/com.romshortcutmaker.app",
    "~/Library/Preferences/com.romshortcutmaker.app.plist",
  ]
end
