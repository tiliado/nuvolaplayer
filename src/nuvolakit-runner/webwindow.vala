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

public class WebWindow: Gtk.Window
{
	private static const int MINIMAL_WIDTH = 100;
	private static const int MINIMAL_HEIGHT = 100;
	private static const int INITIAL_WIDTH = 800;
	private static const int INITIAL_HEIGHT = 600;
	private weak WebKit.WebView web_view;
	
	public WebWindow(WebKit.WebView web_view)
	{
		this.web_view = web_view;
		add(web_view);
		web_view.ready_to_show.connect(on_ready_to_show);
		web_view.close.connect(on_close);
		web_view.notify["title"].connect_after(on_title_changed);
	}
	
	private void on_ready_to_show()
	{
		var properties = web_view.get_window_properties();
		var geom = properties.geometry;
		if (geom.width < MINIMAL_WIDTH || geom.height < MINIMAL_HEIGHT)
		{
			set_default_size(int.max(INITIAL_WIDTH, geom.width), int.max(INITIAL_HEIGHT, geom.height));
			maximize();
		}
		else
		{
			move(geom.x, geom.y);
			set_default_size(geom.width, geom.height);
			if (properties.fullscreen)
				maximize();
		}
		web_view.show();
		present();
	}
	
	private void on_close()
	{
		hide();
		destroy();
	}
	
	private void on_title_changed(GLib.Object o, ParamSpec p)
	{
		title = web_view.title;
	}
}

} // namespace Nuvola
