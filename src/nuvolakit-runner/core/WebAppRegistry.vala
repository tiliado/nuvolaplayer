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
	 * Whether it is allowed to install/remove services.
	 */
	public bool allow_management {get; private set;}
	
	/**
	 * Creates new web app registry
	 * 
	 * @param user_storage        user-specific directory with service integrations
	 * @param system_storage      system-wide directories with service integrations
	 * @param allow_management    whether to allow services management (add/remove)
	 */
	public WebAppRegistry(File user_storage, File[] system_storage, bool allow_management)
	{
		this.user_storage = user_storage;
		this.system_storage = system_storage;
		this.allow_management = allow_management;
	}
	
	/**
	 * Emitted when a service has been installed
	 * 
	 * @param id    service's id
	 */
	public signal void app_installed(string id);
	
	/**
	 * Emitted when a service has been removed
	 * 
	 * @param id    service's id
	 */
	public signal void app_removed(string id);
	
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
	 * Installs web app from a package
	 * 
	 * @param package    package file
	 * @return meta object on the installed web app
	 */
	public WebAppMeta install_app(File package) throws WebAppError
	{
		if (!allow_management)
			throw new WebAppError.NOT_ALLOWED("WebApp management is disabled");
		File tmp_dir;
		try
		{
			tmp_dir = File.new_for_path(DirUtils.make_tmp("nuvolaplayerXXXXXX"));
		}
		catch (FileError e)
		{
			throw new WebAppError.IOERROR(e.message);
		}
		try
		{
			extract_archive_file(package, tmp_dir);
		
			var control_file = tmp_dir.get_child("control");
			string control_data;
			try
			{
				control_data = Diorite.System.read_file(control_file);
			}
			catch (GLib.Error e)
			{
				throw new WebAppError.IOERROR("Cannot read '%s'. %s", control_file.get_path(), e.message);
			}
			
			const string GROUP = "package";
			control_data = "[%s]\n%s".printf(GROUP, control_data);
			var control = new KeyFile();
			string web_app_id;
			try
			{
				control.load_from_data(control_data, -1, KeyFileFlags.NONE);
				var format = control.get_integer(GROUP, "format");
				web_app_id = control.get_string(GROUP, "app_id");
				if (format != 3 || web_app_id == null || web_app_id == "")
					throw new WebAppError.INVALID_FILE("Package has wrong format.");
			}
			catch (KeyFileError e)
			{
				throw new WebAppError.INVALID_FILE("Invalid control file '%s'. %s", control_file.get_path(), e.message);
			}
			
			var web_app_dir = tmp_dir.get_child(web_app_id);
			if (web_app_dir.query_file_type(0) != FileType.DIRECTORY)
				throw new WebAppError.INVALID_FILE("Package does not contain directory '%s'.", web_app_id);
			
			WebAppMeta.load_from_dir(web_app_dir); // throws WebAppError
			
			var destination = user_storage.get_child(web_app_id);
			if (destination.query_exists())
			{
				try
				{
					Diorite.System.purge_directory_content(destination, true);
					destination.delete();
				}
				catch (GLib.Error e)
				{
					throw new WebAppError.IOERROR("Cannot purge dir '%s'. %s", destination.get_path(), e.message);
				}
			}
			else
			{
				try
				{
					destination.get_parent().make_directory_with_parents();
				}
				catch (Error e)
				{
					// Not fatal
				}
			}
			
			try
			{
				var cancellable = new Cancellable();
				Diorite.System.copy_tree(web_app_dir, destination, cancellable);
			}
			catch (GLib.Error e)
			{
				try
				{
					Diorite.System.purge_directory_content(destination, true);
					destination.delete();
				}
				catch (GLib.Error e2)
				{
					warning("Cannot purge dir '%s'. %s", destination.get_path(), e2.message);
				}
				
				throw new WebAppError.IOERROR("Cannot copy integration to '%s'. %s", destination.get_path(), e.message);
			}
			
			var web_app = WebAppMeta.load_from_dir(destination); // throws WebAppError
			app_installed(web_app.id);
			return web_app;
		}
		catch (ArchiveError e)
		{
			throw new WebAppError.EXTRACT_ERROR("Failed to extract package '%s'. %s", package.get_path(), e.message);
		}
		finally
		{
			Diorite.System.try_purge_dir(tmp_dir);
		}
	}
	
	/**
	 * Removes web app.
	 * 
	 * @param app    web_app to remove
	 * @throw        WebAppError on failure
	 */
	public void remove_app(WebAppMeta app) throws WebAppError
	{
		if (!allow_management)
			throw new WebAppError.NOT_ALLOWED("Web app management is disabled");
		
		var dir = app.data_dir;
		if (dir == null)
			throw new WebAppError.IOERROR("Invalid web app directory");
		
		if (dir.query_exists())
		{
			try
			{
				Diorite.System.purge_directory_content(dir, true);
				dir.delete();
				app_removed(app.id);
			}
			catch (GLib.Error e)
			{
				throw new WebAppError.IOERROR(e.message);
			}
		}
		else
		{
			throw new WebAppError.IOERROR("'%s' does not exist.", dir.get_path());
		}
	}
	
	private void extract_archive_file(File archive, File directory)  throws ArchiveError
	{
		Archive.Read reader = new Archive.Read();
		if (reader.support_format_tar() != Archive.Result.OK)
			throw new ArchiveError.READ_ERROR("Cannot enable tar format. %s", reader.error_string());
		if (reader.support_compression_gzip() != Archive.Result.OK)
			throw new ArchiveError.READ_ERROR("Cannot enable gzip compression. %s", reader.error_string());
		if (reader.open_filename(archive.get_path(), 10240) != Archive.Result.OK)
			throw new ArchiveError.READ_ERROR("Cannot open archive '%s'. %s", archive.get_path(), reader.error_string());
		extract_archive(reader, directory);
	}
	
	private void extract_archive_fd(int archive_fd, File directory)  throws ArchiveError
	{
		Archive.Read reader = new Archive.Read();
		if (reader.support_format_tar() != Archive.Result.OK)
			throw new ArchiveError.READ_ERROR("Cannot enable tar format. %s", reader.error_string());
		if (reader.support_compression_gzip() != Archive.Result.OK)
			throw new ArchiveError.READ_ERROR("Cannot enable gzip compression. %s", reader.error_string());
		if (reader.open_fd(archive_fd, 10240) != Archive.Result.OK)
			throw new ArchiveError.READ_ERROR("Cannot open archive fd %d. %s", archive_fd, reader.error_string());
		extract_archive(reader, directory);
	}
	
	private void extract_archive(Archive.Read reader, File directory) throws ArchiveError
	{
		var current_dir = Environment.get_current_dir();
		if (Environment.set_current_dir(directory.get_path()) < 0)
			throw new ArchiveError.SYSTEM_ERROR("Failed to chdir to '%s'.", directory.get_path());
		
		try
		{
			var writer = new Archive.WriteDisk();
			writer.set_options(Archive.ExtractFlags.TIME | Archive.ExtractFlags.SECURE_NODOTDOT | Archive.ExtractFlags.SECURE_SYMLINKS);
			
			while (true)
			{
				unowned Archive.Entry entry;
				var result = reader.next_header(out entry);
				if (result == Archive.Result.EOF)
					break;
				if (result != Archive.Result.OK)
					throw new ArchiveError.READ_ERROR("Failed to read next header. %s", reader.error_string());
				debug("Extract '%s'", entry.pathname());
				if (writer.write_header(entry) != Archive.Result.OK)
					throw new ArchiveError.WRITE_ERROR("Failed to write header. %s", writer.error_string());
				
				void* buff;
				size_t size;
				Archive.off_t offset;
			
				while (true)
				{
					result = reader.read_data_block (out buff, out size, out offset);
					if (result == Archive.Result.EOF)
						break;
					if (result != Archive.Result.OK)
						throw new ArchiveError.READ_ERROR("Failed to read data. %s", reader.error_string());
					if (writer.write_data_block(buff, size, offset) != Archive.Result.OK)
						throw new ArchiveError.WRITE_ERROR("Failed to write data. %s", writer.error_string()); 
				}
				
				if (writer.finish_entry() != Archive.Result.OK)
					throw new ArchiveError.WRITE_ERROR("Failed to finish entry. %s", writer.error_string());
			}
		}
		finally
		{
			reader.close();
			if (Environment.set_current_dir(current_dir) < 0)
				warning("Failed to chdir back to '%s'.", current_dir);
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

public errordomain ArchiveError
{
	SYSTEM_ERROR,
	READ_ERROR,
	WRITE_ERROR;
}

} // namespace Nuvola
