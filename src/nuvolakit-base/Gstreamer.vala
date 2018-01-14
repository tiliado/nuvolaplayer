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

namespace Nuvola.Gstreamer
{
	
	public void init_gstreamer()
	{
		string[] a = {};
		unowned string[] b = a;
		try
		{
			#if FLATPAK
			check_gstreamer_cache();
			#endif
			Gst.init_check(ref b);
		}
		catch(Error e)
		{
			debug("Unable to init %s: %s", Gst.version_string(), e.message);
		}
	}
	
	private void check_gstreamer_cache()
	{
		var gstreamer_cache_dir = File.new_for_path(Environment.get_user_cache_dir() + "/gstreamer-1.0");
		var gstreamer_nuvola_tag = gstreamer_cache_dir.get_child("__nuvola_%d_%d_%d__".printf(VERSION_MAJOR, VERSION_MINOR, VERSION_BUGFIX));
		if (!gstreamer_nuvola_tag.query_exists(null))
		{
			debug("Nuvola GStreamer cache tag does not exist. %s", gstreamer_nuvola_tag.get_path());
			try
			{
				if (gstreamer_cache_dir.query_exists(null))
					Drt.System.purge_directory_content(gstreamer_cache_dir, true);
				Drt.System.make_dirs(gstreamer_cache_dir);
				Drt.System.overwrite_file(gstreamer_nuvola_tag, "Nuvola");
			}
			catch (GLib.Error e)
			{
				warning("Failed to purge gstreamer cache. %s", e.message);
			}
		}
	}
} // namespace Nuvola.Gstreamer
