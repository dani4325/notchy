cask "notchy" do
  version "1.0.0"
  sha256 "6965e7318131cd84f7ff9b7951697bc68cdc3d651221365cffc035ae594d398f"

  url "https://github.com/TU_USUARIO/notchy/releases/download/v#{version}/Notchy-#{version}.zip"
  name "Notchy"
  desc "Dynamic Island-style notch panel with anime themes"
  homepage "https://github.com/TU_USUARIO/notchy"

  depends_on macos: ">= :sequoia"
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
