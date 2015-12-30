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
  <b>Congratulations!</b> You have installed %1$s.
  <a href="https://tiliado.github.io/nuvolaplayer/documentation/3.0/notes.html">Read release notes</a> to find out
  what is new.
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
	
	public WelcomeWindow(Diorite.Application app, Diorite.Storage storage)
	{
		base(app, true);
		title = "Welcome to Nuvola Player";
		set_default_size(1000, 600);
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
		
		var welcome_text = new Diorite.RichTextView(buffer);
		welcome_text.link_opener = show_uri;
		welcome_text.margin = 18;
		var box = new Gtk.EventBox();
		box.override_background_color(Gtk.StateFlags.NORMAL, {1.0, 1.0, 1.0, 1.0});
		var scroll = new Gtk.ScrolledWindow(null, null);
		scroll.add(welcome_text);
		scroll.vexpand = true;
		scroll.hexpand = true;
		grid.attach(scroll, 0, 0, 1, 1);
		web_view = new WebView();
		web_view.load_uri(PATRONS_BOX_URI);
		web_view.margin = 18;
		web_view.decide_policy.connect(on_decide_policy);
		box = new Gtk.EventBox();
		web_view.hexpand = false;
		web_view.vexpand = true;
		web_view.set_size_request(275, -1);
		grid.attach(web_view, 1, 0, 1, 1);
		var button = new Gtk.Button.with_label("Close");
		button.clicked.connect(() => {destroy();});
		button.margin = 10;
		button.margin_right = 18;
		grid.attach(button, 1, 1, 1, 1);
		button.vexpand = button.hexpand = false;
		button.halign = Gtk.Align.END;
		top_grid.add(grid);
		top_grid.show_all();
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
