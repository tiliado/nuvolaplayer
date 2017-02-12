/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola
{

public async void create_desktop_files(WebAppRegistry web_app_reg, bool create_hidden)
{
	Idle.add(create_desktop_files.callback);
	yield;
	var web_apps = web_app_reg.list_web_apps();
	foreach (var web_app in web_apps.get_values())
		if ((create_hidden || !web_app.hidden) && !web_app.has_desktop_launcher)
			yield write_desktop_file(web_app);
}
	
public bool write_desktop_file_sync(WebAppMeta web_app)
{
	var storage = new Diorite.XdgStorage();
	var filename = "%s.desktop".printf(build_dashed_id(web_app.id));
	var file = storage.user_data_dir.get_child("applications").get_child(filename);
	var existed = file.query_exists();
	var data = create_desktop_file(web_app).to_data(null, null);
	try
	{
		Diorite.System.overwrite_file(file, data);
		if (FileUtils.chmod(file.get_path(), 00755) != 0)
			warning("chmod 0755 %s failed.", file.get_path());
	}
	catch (GLib.Error e)
	{
		var readonly = false;
		try
		{
			var info = file.query_info("access::can-write", 0, null);
			readonly = !info.get_attribute_boolean("access::can-write");
		}
		catch (GLib.Error e2)
		{
			warning("Query file info error: %s", e2.message);
		}
		if (readonly)
			message("Desktop launcher '%s' has not been modified because it is read-only.", file.get_path());
		else
			warning("Failed to write key file '%s': %s", file.get_path(), e.message);
	}
	return existed;
}

public async bool write_desktop_file(WebAppMeta web_app)
{
	var file = get_desktop_file(web_app);
	var existed = file.query_exists();
	var data = create_desktop_file(web_app).to_data(null, null);
	try
	{
		yield Diorite.System.overwrite_file_async(file, data);
		if (FileUtils.chmod(file.get_path(), 00755) != 0)
			warning("chmod 0755 %s failed.", file.get_path());
	}
	catch (GLib.Error e)
	{
		var readonly = false;
		try
		{
			var info = file.query_info("access::can-write", 0, null);
			readonly = !info.get_attribute_boolean("access::can-write");
		}
		catch (GLib.Error e2)
		{
			warning("Query file info error: %s", e2.message);
		}
		if (readonly)
			message("Desktop launcher '%s' is read-only.", file.get_path());
		else
			warning("Failed to write key file '%s': %s", file.get_path(), e.message);
	}
	return existed;
}

public KeyFile create_desktop_file(WebAppMeta web_app)
{
	var key_file = new KeyFile();
	const string GROUP = "Desktop Entry";
	key_file.set_string(GROUP, "Name", web_app.name);
	key_file.set_string(GROUP, "Exec", "%s -a %s".printf(Nuvola.get_future_app_id(), web_app.id));
	key_file.set_string(GROUP, "Type", "Application");
	key_file.set_string(GROUP, "Categories", web_app.categories);
	key_file.set_string(GROUP, "Icon", web_app.get_icon_name_or_path(-1) ?? Nuvola.get_app_icon());
	key_file.set_string(GROUP, "StartupWMClass", build_dashed_id(web_app.id));
	key_file.set_boolean(GROUP, "StartupNotify", true);
	key_file.set_boolean(GROUP, "Terminal", false);
	return key_file;
}

public async void delete_desktop_file(WebAppMeta web_app) throws GLib.Error
{
	yield get_desktop_file(web_app).delete_async();
}

public void delete_desktop_file_sync(WebAppMeta web_app)
{
	try
	{
		get_desktop_file(web_app).delete();
	}
	catch (GLib.Error e)
	{
		if (e.code != 1)
			warning("Failed to delete desktop file. %s", e.message);
	}
}

public string get_desktop_file_name(string web_app_id)
{
	return "%s.desktop".printf(build_dashed_id(web_app_id));
}

public File get_desktop_file(WebAppMeta web_app)
{
	var storage = new Diorite.XdgStorage();
	return storage.user_data_dir.get_child("applications").get_child(get_desktop_file_name(web_app.id));
}

public async void delete_desktop_files(GenericSet<string>? filenames_whitelist)
{
	var pattern = new PatternSpec("nuvolaplayer3-*.desktop");
	var dir = new Diorite.XdgStorage().user_data_dir.get_child("applications");
	try
	{
		var enumerator = yield dir.enumerate_children_async(
			FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
		FileInfo info;
		while ((info = enumerator.next_file(null)) != null)
		{
			var name = info.get_name();
			if (pattern.match_string(name))
			{
				if (filenames_whitelist == null || !(name in filenames_whitelist))
				{
					var file = dir.get_child(name);
					try
					{
						yield file.delete_async();
					}
					catch (GLib.Error e)
					{
						warning("Failed to delete desktop file %s. %s", file.get_path(), e.message);
					}
				}
			}
		}
	}
	catch (GLib.Error e)
	{
		warning("Directory enumeration failed: %s. %s\n", dir.get_path(), e.message);
	}
}

private static HashTable<string,string> desktop_categories = null;

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

} // namespace Nuvola
