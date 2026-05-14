class Prping < Formula
  desc "macOS menu-bar app that pings you about GitHub PRs awaiting your review"
  homepage "https://github.com/TamaraVerk/PRPing"
  url "https://github.com/TamaraVerk/PRPing/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "bbe019a42a60ada2d50758ffce51e6b292b49b4a0403df6b90af958077e044d3"
  license "MIT"
  head "https://github.com/TamaraVerk/PRPing.git", branch: "main"

  depends_on "gh"
  depends_on :macos
  depends_on xcode: :build

  def install
    system "./build.sh"
    prefix.install "build/PRPing.app"
    pkgshare.install "hooks"
  end

  service do
    run [opt_prefix/"PRPing.app/Contents/MacOS/PRPing"]
    run_type :immediate
    keep_alive crashed: true, successful_exit: false
    environment_variables PATH: "#{HOMEBREW_PREFIX}/bin:/usr/bin:/bin"
    log_path "#{var}/log/prping.log"
    error_log_path "#{var}/log/prping.err.log"
  end

  def caveats
    <<~EOS
      PRPing needs `gh` authenticated once:
        gh auth login

      Start the menu-bar app now and auto-launch it at login:
        brew services start prping

      The icon appears in the menu bar. Click "Quit PRPing" in the menu
      to stop it (it will not auto-restart on a clean quit). To stop the
      service entirely:
        brew services stop prping

      Optional — wire up the Claude Code hook so PRPing blinks when you
      enter plan / acceptEdits / bypassPermissions mode. Add this to
      ~/.claude/settings.json (Notification hook):
        #{pkgshare}/hooks/plan-mode-trigger.sh
    EOS
  end

  test do
    assert_predicate prefix/"PRPing.app/Contents/MacOS/PRPing", :exist?
  end
end
