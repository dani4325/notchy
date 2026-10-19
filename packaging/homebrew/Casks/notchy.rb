cask "notchy" do
  version "1.0.0"
  sha256 "25ec7125d4153bd22fd0566b14583c88f9ac3cf5f9681ce5dff721bbbf39b5bb"

  url "https://github.com/dani4325/notchy/releases/download/v#{version}/Notchy-#{version}.zip"
  name "Notchy"
  desc "Dynamic Island-style notch panel with anime themes"
  homepage "https://github.com/dani4325/notchy"

  depends_on macos: :sequoia
  depends_on arch: :arm64

  app "Notchy.app"

  zap trash: [
    "~/Library/Application Support/Notchy",
    "~/Library/Preferences/com.danirubio.notchy.plist",
  ]

  caveats <<~EOS
    Notchy is signed with its own certificate and not notarized by Apple.
    The first time you open it, macOS will block it. To allow it:
      System Settings → Privacy & Security → Security → "Open Anyway"
  EOS
end
