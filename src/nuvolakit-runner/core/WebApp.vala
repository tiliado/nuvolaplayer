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
	private const string METADATA_FILENAME = "metadata.json";
	
	public string id {get; construct;}
	public string name {get; construct;}
	public string maintainer_name {get; construct;}
	public string maintainer_link {get; construct;}
	public string categories {get; construct set;}
	public int version_major {get; construct;}
	public int version_minor {get; construct;}
	public int api_major {get; construct;}
	public int api_minor {get; construct;}
	public string? user_agent {get; construct set;}
	public string? html5_audio {get; construct set;}
	public string? requirements {get; construct set;}
	public int window_width {get; construct;}
	public int window_height {get; construct;}
	public File? data_dir {get; private set; default = null;}
	public bool removable {get; set; default = false;}
	public bool hidden {get; set; default = false;}	
	public bool allow_insecure_content {get; set; default = false;}
	public bool has_desktop_launcher {get; set; default = false;}
	private List<IconInfo?> icons = null;
	private bool icons_set = false;
	private Traits? _traits = null;
	
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
			metadata = Diorite.System.read_file(metadata_file).strip();
		}
		catch (GLib.Error e)
		{
			throw new WebAppError.LOADING_FAILED("Cannot read '%s'. %s", metadata_file.get_path(), e.message);
		}
		
		// Prevents a critical warning from Json.gobject_from_data
		if (metadata == null || metadata[0] != '{')
			throw new WebAppError.INVALID_METADATA("Invalid metadata file '%s'. Opening object literal not found.", metadata_file.get_path());
		
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
		meta.data_dir = dir;
		return meta;
	}
	
	/**
	 * Returns true if web app belongs to given category
	 * 
	 * @param category    category id
	 * @return true if web app belongs to given category
	 */
	public bool in_category(string category)
	{
		var categories = this.categories.split(";");
		foreach (var item in categories)
		{
			item = item.strip();
			if (category[0] != 0 && item == category)
				return true;
		}
		return false;
	}
	
	public string[] list_categories()
	{
		string[] result = {};
		var categories = this.categories.split(";");
		foreach (var item in categories)
		{
			item = item.strip().down();
			if (item[0] != 0)
				result += item;
		}
		return result;
	}
	
	public unowned Traits traits()
	{
		if (_traits == null)
		{
			_traits = new Traits(requirements);
			try
			{
				_traits.eval();
			}
			catch (Drt.RequirementError e)
			{
				warning("Failed to parse requirements. %s", e.message);
			}
		}
		return _traits;
	}
	
	public bool check_requirements(FormatSupport format_support) throws Drt.RequirementError
	{
		var traits = this.traits();
		traits.set_from_format_support(format_support);
		debug("Requirements expression: '%s'", requirements);
		var result = traits.eval();
		debug("Requirements expression: '%s' -> %s", requirements, result.to_string());
		return result;
	}
	
	public string? get_icon_name(int size)
	{
		return lookup_theme_icon(size) != null ? "nuvolaplayer3_" + id : null;
	}
	
	public string? get_icon_name_or_path(int size)
	{
		return get_icon_name(size) ?? get_icon_path(size);
	}
	
	/**
	 * Returns icon path for the given size.
	 * 
	 * @param size    minimal size of the icon or `0` for the largest (scalable) icon
	 * @return        path of the icon
	 */
	public string? get_icon_path(int size)
	{
		var theme_icon = lookup_theme_icon(size);
		if (theme_icon != null)
		{
			var path = theme_icon.get_filename();
			if (path != null && path[0] != '\0')
				return path;
		}
		
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
	 * @return        pixbuf with icon scaled to the given size
	 */
	public Gdk.Pixbuf? get_icon_pixbuf(int size) requires (size > 0)
	{		
		var info = lookup_theme_icon(size, Gtk.IconLookupFlags.FORCE_SIZE);
		if (info != null)
		{
			try
			{
				return info.load_icon().copy();
			}
			catch (GLib.Error e)
			{
				warning("Icon pixbuf %d: %s", size, e.message);
			}
		}
		
		lookup_icons();
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
	
	private Gtk.IconInfo? lookup_theme_icon(int size, Gtk.IconLookupFlags flags=0)
	{
		/* Any large icon requested */
		if (size <= 0)
			size = 1024;
		/* Avoid use of SVG icon for small icon sizes because of a too large borders for this icon sizes */	
		else if (size <= 32)
			flags |= Gtk.IconLookupFlags.NO_SVG;
		
		var icon = Gtk.IconTheme.get_default().lookup_icon("nuvolaplayer3_" + id, size, flags);
		if (icon == null)
			debug("Theme icon %s %d not found.", "nuvolaplayer3_" + id, size);
		return icon;
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
		if (window_width < 0)
			throw new WebAppError.INVALID_METADATA("Property window_width must be greater or equal to zero");
		if (window_height < 0)
			throw new WebAppError.INVALID_METADATA("Property window_height must be greater or equal to zero");
		if (maintainer_name == "")
			throw new WebAppError.INVALID_METADATA("Empty 'maintainer_name' entry");
		if (!maintainer_link.has_prefix("http://")
		&&  !maintainer_link.has_prefix("https://")
		&&  !maintainer_link.has_prefix("mailto:"))
			throw new WebAppError.INVALID_METADATA("Empty or invalid 'maintainer_link' entry: '%s'", maintainer_link);
		
		if (!JSApi.is_supported(api_major, api_minor))
			throw new WebAppError.INVALID_METADATA(
				"Requested unsupported NuvolaKit API '%d.%d'.".printf(api_major, api_minor));
		
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
