/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola {

private static HashTable<string, string> desktop_categories = null;

public HashTable<string, string> get_desktop_categories()
{
    if (desktop_categories == null)
    {
        desktop_categories = new HashTable<string, string>(str_hash, str_equal);
        desktop_categories["AudioVideo"] = _("Multimedia");
        desktop_categories["Audio"] = _("Audio");
        desktop_categories["Video"] = _("Video");
        desktop_categories["Development"] = _("Development");
        desktop_categories["Education"] = _("Education");
        desktop_categories["Game"] = _("Game");
        desktop_categories["Graphics"] = _("Graphics");
        desktop_categories["Network"] = _("Network");
        desktop_categories["Office"] = _("Office");
        desktop_categories["Science"] = _("Science");
        desktop_categories["Settings"] = _("Settings");
        desktop_categories["System"] = _("System Tools");
        desktop_categories["Utility"] = _("Accessories");
        desktop_categories["Other"] = _("Other");
    }
    return desktop_categories;
}

public string? get_desktop_category_name(string id)
{
    return get_desktop_categories()[id];
}


public void move_old_xdg_dirs(Drt.Storage old_storage, Drt.Storage new_storage)
{
    try
    {
        Drt.System.move_dir_if_target_not_found(old_storage.user_config_dir, new_storage.user_config_dir);
    }
    catch (GLib.Error e)
    {
        warning("Failed to move old config dir. %s", e.message);
    }
    try
    {
        Drt.System.move_dir_if_target_not_found(old_storage.user_data_dir, new_storage.user_data_dir);
    }
    catch (GLib.Error e)
    {
        warning("Failed to move old data dir. %s", e.message);
    }
    try
    {
        Drt.System.move_dir_if_target_not_found(old_storage.user_cache_dir, new_storage.user_cache_dir);
    }
    catch (GLib.Error e)
    {
        warning("Failed to move old cache dir. %s", e.message);
    }
}

} // namespace Nuvola
