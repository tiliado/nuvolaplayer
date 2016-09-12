/*
 * Copyright 2015 Jiří Janoušek <janousek.jiri@gmail.com>
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

private const string WELCOME_TEXT = """
<h1>%1$s</h1>
<p>
  Congratulations! You have installed %1$s.
  <a href="https://tiliado.github.io/nuvolaplayer/documentation/3.0/notes.html">Read release notes</a> to find out what
  is new.  <b>Nuvola Player 3.0 is the current stable series.</b> New releases 3.0.x receive only bug fixes, but no new
  features except for compatible service integrations. <b>Do you want something more fresh?</b> Check out
  <a href="https://tiliado.github.io/nuvolaplayer/documentation/3.1.html">Nuvola Player 3.1 Rolling Releases</a>.
</p>

<h2>Be connected</h2>
<p>Get informed about new features, new streaming services and bug fixes.</p>
<ul>
  <li>
    Follow Nuvola Player on <a href="https://www.facebook.com/nuvolaplayer">Facebook</a>,
    <a href="https://plus.google.com/110794636546911932554">Google+</a>
    or <a href="https://twitter.com/NuvolaPlayer">Twitter</a>.
  </li>
  <li>
    Subscribe to the Nuvola Player Newsletter: <a href="http://eepurl.com/bLbm5H">weekly (recommended)</a>
    or <a href="http://eepurl.com/bLbtM1">monthly</a>.
  </li>
</ul>

<h2>Explore all features</h2>
<p>We reccommend you to <a href="https://tiliado.github.io/nuvolaplayer/documentation/3.0/explore.html">explore all features</a> including</p>
<ul>
  <li><a href="https://tiliado.github.io/nuvolaplayer/documentation/3.0/explore.html#explore-unity">Unity integration</a></li>
  <li><a href="https://tiliado.github.io/nuvolaplayer/documentation/3.0/explore.html#explore-gnome">GNOME integration</a></li>
  <li><a href="https://tiliado.github.io/nuvolaplayer/documentation/3.0/explore.html#explore-common">Common features</a></li>
  <li><a href="https://tiliado.github.io/nuvolaplayer/documentation/3.0/explore.html#explore-terminal">Command line controller</a></li>
</ul>

<h2>Get help</h2>
<p>Whenever in trouble, select "Help" menu item.</p>
<ul>
  <li><b>Unity</b>: Gear menu button → Help</li>
  <li><b>GNOME</b>: Application menu button → Help</li>
</ul>

<h2>Become a Patron</h2>
<p>
  Development of Nuvola Player depends on voluntary payments from users.
  <a href="https://tiliado.eu/nuvolaplayer/funding/">Support the project</a> financially and enjoy
  <a href="https://tiliado.eu/accounts/group/3/">the benefits of the Nuvola Patron membership</a>.
</p>
""";

public class WelcomeWindow : Diorite.ApplicationWindow
{
	private static const string PATRONS_BOX_URI = "https://tiliado.eu/nuvolaplayer/funding/patrons_list_box/";
	private Gtk.Grid grid;
	private Diorite.Application app;
	private WebView web_view;
	private Diorite.RichTextView welcome_text;
	private Gtk.ScrolledWindow scroll;
	
	public WelcomeWindow(Diorite.Application app, Diorite.Storage storage)
	{
		base(app, true);
		title = "Welcome to Nuvola Player";
		set_default_size(1000, 800);
		try
		{
			icon = Gtk.IconTheme.get_default().load_icon(app.icon, 48, 0);
		}
		catch (Error e)
		{
			warning("Unable to load application icon.");
		}
		
		this.app = app;
		
		grid = new Gtk.Grid();
		grid.override_background_color(Gtk.StateFlags.NORMAL, {1.0, 1.0, 1.0, 1.0});
		grid.orientation = Gtk.Orientation.VERTICAL;
		var buffer = new Diorite.RichTextBuffer();
		try
		{
			buffer.load(WELCOME_TEXT.printf(get_welcome_screen_name()));
		}
		catch (MarkupError e)
		{
			warning("Markup Error: %s", e.message);
			destroy();
			return;
		}
		
		welcome_text = new Diorite.RichTextView(buffer);
		welcome_text.link_opener = show_uri;
		welcome_text.margin = 18;
		welcome_text.vexpand = welcome_text.hexpand = true;
		welcome_text.motion_notify_event.connect(on_motion_notify);
		grid.attach(welcome_text, 0, 0, 1, 1);
		
		web_view = new WebView();
		web_view.add_events(Gdk.EventMask.SCROLL_MASK);
		web_view.motion_notify_event.connect(on_motion_notify);
		web_view.scroll_event.connect(on_scroll_event);
		web_view.load_changed.connect(on_load_changed);
		web_view.load_uri(PATRONS_BOX_URI);
		web_view.margin = 18;
		web_view.decide_policy.connect(on_decide_policy);
		web_view.hexpand = false;
		web_view.vexpand = true;
		web_view.set_size_request(275, -1);
		grid.attach(web_view, 1, 0, 1, 1);
		
		var button = new Gtk.Button.with_label("Close");
		button.clicked.connect(() => {destroy();});
		button.margin = 10;
		button.margin_right = 18;
		button.margin_top = 0;
		button.vexpand = button.hexpand = false;
		button.halign = Gtk.Align.END;
		grid.attach(button, 1, 1, 1, 1);
		
		scroll = new Gtk.ScrolledWindow(null, null);
		scroll.add(grid);
		scroll.vexpand = true;
		scroll.hexpand = true;
		top_grid.add(scroll);
		top_grid.show_all();
	}
	
	private bool on_scroll_event(Gdk.EventScroll event)
	{
		/* Propagate the scroll event to the ScrolledWindow. */
		scroll.scroll_event(event);
		return true;
	}
	
	private bool on_motion_notify(Gtk.Widget widget, Gdk.EventMotion event)
	{
		if (!widget.has_focus)
		{
			/* The focus grab is necessary for a WebView in a ScrolledWindow as it jumps on click otherwise.
			 * Since the scroll position moves to top on focus grab, it's necessary to restore the original
			 * position after that. */
			var adjustment = scroll.get_vadjustment();
			var position = adjustment.value;
			widget.grab_focus();
			adjustment.value = position;
		}
		return false;
	}
	
	private void on_load_changed(WebKit.WebView view, WebKit.LoadEvent event)
	{
		if (event == WebKit.LoadEvent.FINISHED)
			set_web_view_height();
	}
	
	private bool set_web_view_height()
	{
		/* A hack to get the document height. */
		web_view.run_javascript.begin("""
			var bodyElm = document.body, htmlElm = document.documentElement;
			document.title = Math.max(
				bodyElm.scrollHeight, bodyElm.offsetHeight, 
                htmlElm.clientHeight, htmlElm.scrollHeight, htmlElm.offsetHeight);
			""", null, on_height_retrieved);
		return true;
	}
	
	private void on_height_retrieved(GLib.Object? o, AsyncResult result)
	{
		try
		{
			web_view.run_javascript.end(result);
			var page_height = int.parse(web_view.title);
			int width; int height;
			web_view.get_size_request(out width, out height);
			if (height < page_height && page_height > 100)
				web_view.set_size_request(width, page_height);
		}
		catch (GLib.Error e)
		{
			debug("JavaScript error: %s", e.message);
		}
	}
	
	private void show_uri(string uri)
	{
		app.show_uri(uri);
	}
	
	private bool decide_navigation_policy(bool new_window, WebKit.NavigationPolicyDecision decision)
	{
		var uri = decision.request.uri;
		if (!uri.has_prefix("http://") && !uri.has_prefix("https://") || uri == PATRONS_BOX_URI)
			return false;
		
		show_uri(uri);
		decision.ignore();
		return true;
	}
	
	private bool on_decide_policy(WebKit.PolicyDecision decision, WebKit.PolicyDecisionType decision_type)
	{
		switch (decision_type)
		{
		case WebKit.PolicyDecisionType.NAVIGATION_ACTION:
			return decide_navigation_policy(false, (WebKit.NavigationPolicyDecision) decision);
		case WebKit.PolicyDecisionType.NEW_WINDOW_ACTION:
			return decide_navigation_policy(true, (WebKit.NavigationPolicyDecision) decision);
		case WebKit.PolicyDecisionType.RESPONSE:
		default:
			return false;
		}
	}
}

} // namespace Nuvola
