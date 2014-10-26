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

public void create_desktop_file(WebAppMeta web_app)
{
	var app_id = Nuvola.get_app_id();
	var storage = new Diorite.XdgStorage();
	var dashed_id = build_dashed_id(web_app.id);
	var filename = "%s.desktop".printf(dashed_id);
	var file = storage.user_data_dir.get_child("applications").get_child(filename);
	var key_file = new KeyFile();
	const string GROUP = "Desktop Entry";
	key_file.set_string(GROUP, "Name", web_app.name);
	key_file.set_string(GROUP, "Exec", "%s -a %s".printf(app_id, web_app.id));
	key_file.set_string(GROUP, "Type", "Application");
	key_file.set_string(GROUP, "Categories", web_app.categories);
	key_file.set_string(GROUP, "Icon", web_app.icon ?? Nuvola.get_app_icon());
	key_file.set_string(GROUP, "StartupWMClass", dashed_id);
	key_file.set_boolean(GROUP, "StartupNotify", true);
	key_file.set_boolean(GROUP, "Terminal", false);
	var data = key_file.to_data(null, null);
	try
	{
		Diorite.System.overwrite_file(file, data);
		if (FileUtils.chmod(file.get_path(), 00755) != 0)
			warning("chmod 0755 %s failed.", file.get_path());
	}
	catch (GLib.Error e)
	{
		warning("Failed to write key file '%s': %s", file.get_path(), e.message);
	}
}

} // namespace Nuvola
