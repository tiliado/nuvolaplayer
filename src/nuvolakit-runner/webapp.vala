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

public class WebAppMeta : GLib.Object
{
	/**
	 * Name of file with metadata.
	 */
	private static const string METADATA_FILENAME = "metadata.json";
	
	public string id {get; construct;}
	public string name {get; construct;}
	public string maintainer_name {get; construct;}
	public string maintainer_link {get; construct;}
	public string categories {get; construct set;}
	public int version_major {get; construct;}
	public int version_minor {get; construct;}
	public int api_major {get; construct;}
	public int api_minor {get; construct;}
	public File? data_dir {get; private set; default = null;}
	public bool removable {get; set; default = false;}
	public string? icon
	{
		owned get
		{
			if (data_dir == null)
				return null;
			var file = data_dir.get_child("icon.svg");
			if (file.query_file_type(0) == FileType.REGULAR)
				return file.get_path();
			file = data_dir.get_child("icon.png");
			if (file.query_file_type(0) == FileType.REGULAR)
				return file.get_path();
			return null;
		}
	}
	
	public static WebAppMeta load_from_dir(File dir) throws WebAppError
	{
		if (dir.query_file_type(0) != FileType.DIRECTORY)
			throw new WebAppError.LOADING_FAILED(@"$(dir.get_path()) is not a directory");
		
		var metadata_file = dir.get_child(METADATA_FILENAME);
		if (metadata_file.query_file_type(0) != FileType.REGULAR)
			throw new WebAppError.LOADING_FAILED(@"$(metadata_file.get_path()) is not a file");
		
		string metadata;
		try
		{
			metadata = Diorite.System.read_file(metadata_file);
		}
		catch (GLib.Error e)
		{
			throw new WebAppError.LOADING_FAILED("Cannot read '%s'. %s", metadata_file.get_path(), e.message);
		}
		
		WebAppMeta? meta;
		try
		{
			meta = Json.gobject_from_data(typeof(WebAppMeta), metadata) as WebAppMeta;
		}
		catch (GLib.Error e)
		{
			throw new WebAppError.INVALID_METADATA("Invalid metadata file '%s'. %s", metadata_file.get_path(), e.message);
		}
		
		meta.check();

//			FIXME:
//~ 		if(!JSApi.is_supported(api_major, api_minor)){
//~ 			throw new ServiceError.LOADING_FAILED(
//~ 				"Requested unsupported api: %d.%d'".printf(api_major, api_minor));
//~ 		}
		meta.data_dir = dir;
		return meta;
	}
	
	public void check() throws WebAppError
	{
		if (!WebAppRegistry.check_id(id))
			throw new WebAppError.INVALID_METADATA("Invalid app id '%s'.", id);
		if (name == "")
			throw new WebAppError.INVALID_METADATA("Empty 'name' entry");
		if (version_major <= 0)
			throw new WebAppError.INVALID_METADATA("Major version must be greater than zero");
		if (version_minor < 0)
			throw new WebAppError.INVALID_METADATA("Minor version must be greater or equal to zero");
		if (api_major <= 0)
			throw new WebAppError.INVALID_METADATA("Major api_version must be greater than zero");
		if (api_minor < 0)
			throw new WebAppError.INVALID_METADATA("Minor api_version must be greater or equal to zero");
		if (maintainer_name == "")
			throw new WebAppError.INVALID_METADATA("Empty 'maintainer_name' entry");
		if (!maintainer_link.has_prefix("http://")
		&&  !maintainer_link.has_prefix("https://")
		&&  !maintainer_link.has_prefix("mailto:"))
			throw new WebAppError.INVALID_METADATA("Empty or invalid 'maintainer_link' entry: '%s'", maintainer_link);
		
		if (categories == null || categories == "")
		{
			categories = "Network;";
			warning("Empty 'categories' entry for web app '%s'. Using '%s' as a fallback.", id, categories);
		}
	}
}

public class WebApp : GLib.Object
{
	public WebAppMeta meta {get; construct;}
	public File user_config_dir {get; construct;}
	public File user_data_dir {get; construct;}
	public File user_cache_dir {get; construct;}
	
	public WebApp(WebAppMeta meta, File user_config_dir, File user_data_dir, File user_cache_dir)
	{
		Object(meta: meta, user_config_dir: user_config_dir, user_data_dir:user_data_dir, user_cache_dir:user_cache_dir);
	}
}

} // namespace Nuvola
