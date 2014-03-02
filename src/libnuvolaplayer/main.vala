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
private extern const string APPNAME;
private extern const string NAME;
private extern const string VERSION;
private extern const int VERSION_MAJOR;
private extern const int VERSION_MINOR;
private extern const int VERSION_BUGFIX;
private extern const string VERSION_SUFFIX;


public string get_appname()
{
	return APPNAME;
}

public string get_display_name()
{
	return NAME;
}

public string get_version()
{
	return VERSION;
}

public string get_version_suffix()
{
	return VERSION_SUFFIX;
}

public int[] get_versions()
{
	return {VERSION_MAJOR, VERSION_MINOR, VERSION_BUGFIX};
}

public void list_web_apps()
{
	var storage = new Diorite.XdgStorage.for_project(APPNAME);
	var web_apps_storage = storage.get_child("web_apps");
	web_apps_storage = new Diorite.Storage(
		"data/nuvolaplayer3/web_apps", {},
		web_apps_storage.user_config_dir.get_path(),
		web_apps_storage.user_cache_dir.get_path()
	);
	var web_apps_reg = new WebAppRegistry(web_apps_storage, false);
	var web_apps = web_apps_reg.list_web_apps();
	foreach (var web_app in web_apps.get_values())
	{
		message("Web app: %s, %u.%u, %s", web_app.meta.name, web_app.meta.version_major, web_app.meta.version_minor, web_app.data_dir.get_path());
	}
}


} // namespace Nuvola
