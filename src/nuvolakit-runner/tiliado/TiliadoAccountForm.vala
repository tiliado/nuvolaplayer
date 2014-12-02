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

private class Tiliado.AccountForm: Gtk.Grid
{
	private Account account;
	private Gtk.Entry? username = null;
	private Gtk.Entry? password = null;
	private SList<Gtk.Button> buttons = null;
	private Gtk.InfoBar info_bar;
	private Gtk.Label info_bar_label;
	
	public AccountForm(Account account)
	{
		this.account = account;
		column_spacing = 10;
		row_spacing = 10;
		margin = 10;
		info_bar = new Gtk.InfoBar();
		info_bar.no_show_all = true;
		info_bar_label = new Gtk.Label("");
		info_bar.get_content_area().add(info_bar_label);
		info_bar_label.show();
		display_user_info(account.tiliado.current_user);
		account.tiliado.notify["current-user"].connect_after(on_current_user_changed);
	}
	
	private void display_user_info(User? user)
	{
		buttons = null;
		foreach (var child in get_children())
			remove(child);
		
		Gtk.Label label;
		Gtk.Button button;
		attach(info_bar, 0, 0, 2, 1);
		if (user == null || ! user.is_authenticated)
		{
			label = new Gtk.Label("Username:");
			attach(label, 0, 1, 1, 1);
			username = new Gtk.Entry();
			attach(username, 1, 1, 1, 1);
			label = new Gtk.Label("Password:");
			attach(label, 0, 2, 1, 1);
			password = new Gtk.Entry();
			password.visibility = false;
			attach(password, 1, 2, 1, 1);
			button = new Gtk.Button.with_label("Log in");
			button.clicked.connect(on_login_clicked);
			buttons.prepend(button);
			attach(button, 0, 3, 2, 1);
			button = new Gtk.LinkButton.with_label(account.server + "/accounts/profile/", "Forgot password?");
			attach(button, 0, 4, 2, 1);
			button = new Gtk.LinkButton.with_label(account.server + "/accounts/signup/", "Don't have an account?");
			attach(button, 0, 5, 2, 1);
		}
		else
		{
			username = null;
			password = null;
			label = new Gtk.Label("Username:");
			attach(label, 0, 1, 1, 1);
			label = new Gtk.Label(user.username);
			attach(label, 1, 1, 1, 1);
			label = new Gtk.Label("Name:");
			attach(label, 0, 2, 1, 1);
			label = new Gtk.Label(user.name);
			attach(label, 1, 2, 1, 1);
			button = new Gtk.LinkButton.with_label(account.server + "/accounts/profile/", "Visit profile page");
			attach(button, 0, 3, 2, 1);
			button = new Gtk.Button.with_label("Refresh");
			button.clicked.connect(on_refresh_clicked);
			buttons.prepend(button);
			attach(button, 0, 4, 1, 1);
			button = new Gtk.Button.with_label("Log out");
			button.clicked.connect(on_logout_clicked);
			buttons.prepend(button);
			attach(button, 1, 4, 1, 1);
		}
		show_all();
	}
	
	private void on_current_user_changed(GLib.Object o, ParamSpec p)
	{
		display_user_info(account.tiliado.current_user);
	}
	
	private void set_message(Gtk.MessageType type, string message)
	{
		info_bar.message_type = type;
		info_bar_label.label = message;
		info_bar.show();
	}
	
	private void set_buttons_sensitive(bool sensitive)
	{
		foreach (var button in buttons)
			button.sensitive = sensitive;
	}
	
	private void on_login_clicked(Gtk.Button button)
	{
		set_buttons_sensitive(false);
		account.login.begin(username.text.strip(), password.text.strip(), continue_on_login_clicked);
	}
	
	private void continue_on_login_clicked(GLib.Object? o, AsyncResult res)
	{
		try
		{
			account.login.end(res);
			info_bar.hide();
		}
		catch (ApiError e)
		{
			set_message(Gtk.MessageType.ERROR, e.message);
			warning("%s", e.message);
		}
		set_buttons_sensitive(true);
	}
	
	private void on_logout_clicked(Gtk.Button button)
	{
		set_buttons_sensitive(false);
		account.logout.begin(continue_on_logout_clicked);
	}
	
	private void continue_on_logout_clicked(GLib.Object? o, AsyncResult res)
	{
		try
		{
			account.logout.end(res);
			info_bar.hide();
		}
		catch (ApiError e)
		{
			set_message(Gtk.MessageType.ERROR, e.message);
			warning("%s", e.message);
		}
		set_buttons_sensitive(true);
	}
	
	private void on_refresh_clicked(Gtk.Button button)
	{
		set_buttons_sensitive(false);
		account.refresh.begin(continue_on_refresh_clicked);
	}
	
	private void continue_on_refresh_clicked(GLib.Object? o, AsyncResult res)
	{
		try
		{
			account.refresh.end(res);
			set_message(Gtk.MessageType.INFO, "Data has been refreshed from server.");
		}
		catch (ApiError e)
		{
			set_message(Gtk.MessageType.ERROR, e.message);
			warning("%s", e.message);
		}
		set_buttons_sensitive(true);
	}
}

} // namespace Nuvola
