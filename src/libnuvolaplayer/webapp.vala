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
	public string id {get; construct;}
	public string name {get; construct;}
	public string maintainer_name {get; construct;}
	public string maintainer_link {get; construct;}
	public int version_major {get; construct;}
	public int version_minor {get; construct;}
	public int api_major {get; construct;}
	public int api_minor {get; construct;}
	
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
	}
}

public class WebApp : GLib.Object
{
	public WebAppMeta meta {get; construct;}
	public File config_dir {get; construct;}
	public File data_dir {get; construct;}
	public bool removable {get; construct;}
	public string? icon
	{
		owned get
		{
			var file = data_dir.get_child("icon.svg");
			if (file.query_file_type(0) == FileType.REGULAR)
				return file.get_path();
			file = data_dir.get_child("icon.png");
			if (file.query_file_type(0) == FileType.REGULAR)
				return file.get_path();
			return null;
		}
	}
	
	public WebApp(WebAppMeta meta, File config_dir, File data_dir, bool removable)
	{
		Object(meta: meta, config_dir: config_dir, data_dir: data_dir, removable: removable);
	}

}

} // namespace Nuvola
