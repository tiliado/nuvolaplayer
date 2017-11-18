/*
 * Copyright 2017 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution. 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if FLATPAK
namespace Nuvola.Flatpak
{

public void check_desktop_portal_available(Cancellable? cancellable = null) throws GLib.Error
{
    var conn = Bus.get_sync(BusType.SESSION, cancellable);
    const string NAME = "org.freedesktop.portal.Desktop";
    const string PATH = "/org/freedesktop/portal/desktop";
    try
    {
        conn.call_sync(
            NAME, PATH, "org.freedesktop.portal.OpenURI", "OpenURI",
                null, null, DBusCallFlags.NONE, 60000, cancellable);
    }
    catch (GLib.Error e)
    {
        if (!(e is DBusError.INVALID_ARGS))
            throw e; 
    }
    try
    {
        conn.call_sync(NAME, PATH, "org.freedesktop.portal.ProxyResolver", "Lookup",
            null, null, DBusCallFlags.NONE, 100, cancellable);
    }
    catch (GLib.Error e)
    {
        if (!(e is DBusError.INVALID_ARGS))
            throw e; 
    }
}

private void clear_fontconfig_cache() {
    var fontconfig_cache_dir = File.new_for_path(Environment.get_user_cache_dir() + "/fontconfig");
    var fontconfig_nuvola_tag = fontconfig_cache_dir.get_child("--fontconfig-nuvola-tag-1--");
    if (!fontconfig_nuvola_tag.query_exists(null)) {
        debug("Nuvola fontconfig cache tag does not exist. %s", fontconfig_nuvola_tag.get_path());
        try {
            if (fontconfig_cache_dir.query_exists(null)) {
                Drt.System.purge_directory_content(fontconfig_cache_dir, true);
            }
            Drt.System.make_dirs(fontconfig_cache_dir);
            Drt.System.overwrite_file(fontconfig_nuvola_tag, "Nuvola");
        } catch (GLib.Error e) {
            warning("Failed to purge fontconfig cache. %s", e.message);
        }
    }
}

} // namespace Nuvola.Flatpak
#endif
