
/****************************************************************************
 * Personal overrides (appended after Betterfox 154 into each profile's     *
 * user.js by home/run_after_firefox.sh). Edit here, then `chezmoi apply`.  *
****************************************************************************/
// DNS: AdGuard on the LAN filters DNS; Firefox's own DoH would bypass it.
user_pref("network.trr.mode", 5);
// Passwords live in Bitwarden/Vaultwarden, not in Firefox.
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);
// Start fresh on the home page (no restored tabs, no "restore session" prompt).
user_pref("browser.startup.page", 1);
user_pref("browser.sessionstore.resume_from_crash", false);
// Classic horizontal tabs, no sidebar (the rest is hidden in userChrome.css).
user_pref("sidebar.revamp", false);
user_pref("sidebar.verticalTabs", false);
user_pref("sidebar.visibility", "hide-sidebar");
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.sidebar", false);
// No bookmarks toolbar, no star in the URL bar.
user_pref("browser.toolbars.bookmarks.visibility", "never");
// Remaining telemetry that Betterfox leaves on.
user_pref("toolkit.telemetry.pioneer-new-studies-available", false);
user_pref("toolkit.telemetry.dap_enabled", false);
user_pref("dom.private-attribution.submission.enabled", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);
user_pref("breakpad.reportURL", "");
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
user_pref("browser.vpn_promo.enabled", false);
user_pref("extensions.getAddons.showPane", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("messaging-system.rsexperimentloader.enabled", false);
user_pref("network.connectivity-service.enabled", false);
// Dark web content to match Catppuccin Mocha (0 = dark).
user_pref("layout.css.prefers-color-scheme.content-override", 0);
// Links always open as tabs, never new windows: normal links (3 = new tab),
// script popups with a window size (restriction 0 = ignore the size, use a tab),
// and links sent from other apps (kitty, mail, ...).
user_pref("browser.link.open_newwindow", 3);
user_pref("browser.link.open_newwindow.restriction", 0);
user_pref("browser.link.open_newwindow.override.external", 3);
// New tabs show home.example.org with an empty, focused address bar: set by
// firefox/mozilla.cfg (AutoConfig), not by a pref.

// Translations: never offer to translate English or German pages (other languages still get the offer).
user_pref("browser.translations.neverTranslateLanguages", "en,de");
