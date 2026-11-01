# applied to every KDE config copied onto the gaming PC
# taskbar: this PC's own pinned apps (the T480 snapshot has fewer); Brave first, in Firefox's old slot
s#^launchers=.*applications:\(org\.mozilla\.\)\?firefox\.desktop.*#launchers=applications:brave-browser.desktop,applications:org.kde.dolphin.desktop,applications:ygo-omega.desktop,applications:kitty.desktop,applications:codium.desktop,applications:org.jellyfin.JellyfinDesktop.desktop,applications:steam.desktop,applications:com.discordapp.Discord.desktop,applications:com.bambulab.BambuStudio.desktop#
# Meta+B opens Brave (Firefox stays installed)
s#^\[services\]\[firefox\.desktop\]$#[services][brave-browser.desktop]#
