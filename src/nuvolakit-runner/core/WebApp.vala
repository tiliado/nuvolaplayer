/*
 * Copyright 2014-2015 Jiří Janoušek <janousek.jiri@gmail.com>
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
	public bool hidden {get; set; default = false;}	
	private List<IconInfo?> icons = null;
	private bool icons_set = false;
	
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
	
	/**
	 * Returns icon path for the given size.
	 * 
	 * @param size    minimal size of the icon or `0` for the largest (scalable) icon
	 * @return        path of the icon
	 */
	public string? get_icon_path(int size)
	{
		lookup_icons();
		if (size <= 0)
			return icons != null ? icons.last().data.path : get_old_main_icon();
		
		foreach (var icon in icons)
			if (icon.size <= 0 || icon.size >= size)
				return icon.path;
		
		return get_old_main_icon();
	}
	
	/**
	 * Returns icon pixbuf for the given size.
	 * 
	 * @param size    minimal size of the icon or `0` for the largest (scalable) icon
	 * @return        pixbuf with icon scaled to the given size
	 */
	public Gdk.Pixbuf? get_icon_pixbuf(int size)
	{		
		lookup_icons();
		if (size <= 0)
		{
			/* Return the largest icon */
			unowned List<IconInfo?>? cursor = icons != null ? icons.last() : null;
			while (cursor != null)
			{
				unowned IconInfo icon = cursor.data;
				try
				{
					var pixbuf = new Gdk.Pixbuf.from_file_at_scale(icon.path, size, size, false);
					if (pixbuf != null)
						return pixbuf;
				}
				catch (GLib.Error e)
				{
					warning("Failed to load icon from file %s: %s", icon.path, e.message);
				}
				cursor = cursor.prev;
			}
		}
		else
		{
			/* Return the first icon >= size */
			foreach (var icon in icons)
			{
				if (icon.size <= 0 || icon.size >= size)
				{
					try
					{
						var pixbuf =  new Gdk.Pixbuf.from_file_at_scale(icon.path, size, size, false);
						if (pixbuf != null)
							return pixbuf;
					}
					catch (GLib.Error e)
					{
						warning("Failed to load icon from file %s: %s", icon.path, e.message);
					}
				}
			}
		}
		
		var default_icon = get_old_main_icon();
		if (default_icon != null)
		{
			try
			{
				var pixbuf =  new Gdk.Pixbuf.from_file_at_scale(default_icon, size, size, false);
				if (pixbuf != null)
					return pixbuf;
			}
			catch (GLib.Error e)
			{
				warning("Failed to load icon from file %s: %s", default_icon, e.message);
			}
		}
		
		return Diorite.Icons.load_theme_icon({Nuvola.get_app_icon()}, size);
	}
	
	private void lookup_icons(bool refresh=false)
	{
		if (data_dir == null || icons_set && !refresh)
			return;
		
		icons = null;
		var icons_dir = data_dir.get_child("icons");
		try
		{
			FileInfo file_info;
			var enumerator = icons_dir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
			while ((file_info = enumerator.next_file()) != null)
			{
				int width = 0;
				int height = 0;
				var path = icons_dir.get_child(file_info.get_name()).get_path();
				var format = Gdk.Pixbuf.get_file_info(path, out width, out height);
				if (format == null)
					continue;
				
				var size = path.has_suffix(".svg") ? 0 : int.min(width, height);
				icons.prepend({path, size});
			}
		}
		catch (GLib.Error e)
		{
			if (!(e is GLib.IOError.NOT_FOUND))
				warning("Enumeration of icons failed (%s): %s", icons_dir.get_path(), e.message);
		}
		
		icons.sort(IconInfo.compare);
		icons_set = true;
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
	
	private string? get_old_main_icon()
	{
		// TODO: get rid of old main icon
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
	
	public static inline int cmp_by_name(WebAppMeta a, WebAppMeta b)
	{
		return strcmp(a.name, b.name);
	}
	
	private struct IconInfo
	{
		string path;
		int size;
		
		public static int compare(IconInfo? icon1, IconInfo? icon2)
		{
			return_val_if_fail(icon1 != null && icon2 != null, 0);
			
			if (icon1.size == icon2.size)
				return 0;
			if (icon1.size <= 0)
				return 1;
			if (icon2.size <= 0)
				return -1;
			
			return icon1.size - icon2.size;
		}
	}
}

} // namespace Nuvola
