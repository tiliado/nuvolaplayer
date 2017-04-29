/*
 * Copyright 2011-2016 Jiří Janoušek <janousek.jiri@gmail.com>
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

/**
 *  WebAppRegistry deals with management and loading of web apps from filesystem.
 */
public class WebAppRegistry: GLib.Object
{
	private File user_storage;
	private File[] system_storage;
	
	/**
	 * Regular expression to check validity of service identifier
	 */
	private static Regex id_regex;
	
	/**
	 * Creates new web app registry
	 * 
	 * @param user_storage        user-specific directory with service integrations
	 * @param system_storage      system-wide directories with service integrations
	 */
	public WebAppRegistry(File user_storage, File[] system_storage)
	{
		this.user_storage = user_storage;
		this.system_storage = system_storage;
	}
	
	/**
	 * Return web app by id.
	 */
	public WebAppMeta? get_app_meta(string id)
	{
		if  (!check_id(id))
		{
			warning("Service id '%s' is invalid.", id);
			return null;
		}
		
		var apps = list_web_apps(id);
		var app = apps[id];
		
		if (app != null)
			message("Using web app %s, version %u.%u, data dir %s", app.name, app.version_major, app.version_minor,
				app.data_dir == null ? "(null)" : app.data_dir.get_path());
		else
			message("Web App %s not found.", id);
		
		return app;
	}
	
	/**
	 * Lists available web apps
	 * 
	 * @param filter_id    if not null, filter apps by id
	 * @return hash table of web app id - metadata pairs
	 */
	public HashTable<string, WebAppMeta> list_web_apps(string? filter_id=null)
	{
		HashTable<string,  WebAppMeta> result = new HashTable<string, WebAppMeta>(str_hash, str_equal);
		find_apps(user_storage, filter_id, result);
		foreach (var dir in system_storage)
			find_apps(dir, filter_id, result);
		return result;
	}
	
	private void find_apps(File directory, string? filter_id, HashTable<string,  WebAppMeta> result)
	{
		if (directory.query_exists())
		{
			try
			{
				FileInfo file_info;
				var enumerator = directory.enumerate_children(FileAttribute.STANDARD_NAME, 0);
				while ((file_info = enumerator.next_file()) != null)
				{
					string dirname = file_info.get_name();
					var app_dir = directory.get_child(dirname);
					if (app_dir.query_file_type(0) != FileType.DIRECTORY)
						continue;
					
					try
					{
						var app = WebAppMeta.load_from_dir(app_dir);
						app.removable = false;
						var id = app.id;
						debug("Found web app %s at %s, version %u.%u",
						app.name, app_dir.get_path(), app.version_major, app.version_minor);
						
						if (filter_id == null || filter_id == id)
						{
							unowned WebAppMeta? prev_app = result[id];
							// Insert new value, if web app has not been added yet,
							// or override previous web app integration, if
							// the new one has greater version.
							if(prev_app == null
							|| app.version_major > prev_app.version_major
							|| app.version_major == prev_app.version_major && app.version_minor > prev_app.version_minor)
								result[id] = app;
						}
					}
					catch (WebAppError e)
					{
						warning("Unable to load app from %s: %s", app_dir.get_path(), e.message);
					}
				}
			}
			catch (GLib.Error e)
			{
				warning("Filesystem error: %s", e.message);
			}
		}
	}
	
	/**
	 * Check if the service identifier is valid
	 * 
	 * @param id service identifier
	 * @return true if id is valid
	 */
	public static bool check_id(string id)
	{
		const string ID_REGEX = "^[a-z0-9]+(?:_[a-z0-9]+)*$";
		if (id_regex == null)
		{
			try
			{
				id_regex = new Regex(ID_REGEX);
			}
			catch (RegexError e)
			{
				error("Unable to compile regular expression /%s/.", ID_REGEX);
			}
		}
		return id_regex.match(id);
	}
}

public errordomain WebAppError
{
	INVALID_METADATA,
	LOADING_FAILED,
	COMMAND_FAILED,
	INVALID_FILE,
	IOERROR,
	NOT_ALLOWED,
	SERVER_ERROR,
	SERVER_ERROR_MESSAGE,
	EXTRACT_ERROR;
}

} // namespace Nuvola
