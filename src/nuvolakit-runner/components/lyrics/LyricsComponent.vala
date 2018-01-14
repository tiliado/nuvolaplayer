/*
 * Copyright 2015-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class LyricsComponent: Component
{
	#if !NUVOLA_LITE
	private Bindings bindings;
	private AppRunnerController app;
	private LyricsSidebar? sidebar = null;
	#endif
	
	public LyricsComponent(AppRunnerController app, Bindings bindings, Drt.KeyValueStorage config)
	{
		base("lyrics", "Lyrics", "Shows lyrics for the current song.");
		#if !NUVOLA_LITE
		this.bindings = bindings;
		this.app = app;
		config.bind_object_property("component.%s.".printf(id), this, "enabled").set_default(true).update_property();
		auto_activate = false;
		#else
		available = false;
		#endif
	}
	
	#if !NUVOLA_LITE
	protected override bool activate()
	{
		SList<LyricsFetcher> fetchers = null;
		fetchers.append(new LyricsFetcherCache(app.storage.get_cache_path("lyrics")));
		fetchers.append(new AZLyricsFetcher(app.connection.session));
		var provider = new LyricsProvider(bindings.get_model<MediaPlayerModel>(), (owned) fetchers);
		sidebar = new LyricsSidebar(app, provider);
		app.main_window.sidebar.add_page("lyricssidebar", _("Lyrics"), sidebar);
		return true;
	}
	
	protected override bool deactivate()
	{
		app.main_window.sidebar.remove_page(sidebar);
		sidebar = null;
		return true;
	}
	#endif
}

} // namespace Nuvola
