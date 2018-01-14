/*
 * Copyright 2016-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class TiliadoAccountWidget : Gtk.Grid
{
	public bool full_width {get; private set; default = true;}
	private Gtk.Orientation orientation;
	private Gtk.Button? activate_button;
	private Gtk.Button? plan_button = null;
	private Gtk.Button? free_button = null;
	private Gtk.Button? cancel_button = null;
	private Gtk.Button? logout_button = null;
	private Gtk.Label? status_label = null;
	private Gtk.Grid button_box;
	private TiliadoActivation activation;
	private TiliadoApi2.User? current_user = null;
	private Drtgtk.Application app;
	
	public TiliadoAccountWidget(TiliadoActivation activation, Drtgtk.Application app, Gtk.Orientation orientation)
	{
		this.activation = activation;
		this.app = app;
		this.orientation = orientation;
		button_box = new Gtk.Grid();
		button_box.orientation = Gtk.Orientation.HORIZONTAL;
		button_box.column_spacing = 5;
		margin = 5;
		margin_left = margin_right = 10;
		row_spacing = column_spacing = 5;
		
		activation.user_info_updated.connect(on_user_info_updated);
		activation.activation_started.connect(on_activation_started);
		activation.activation_failed.connect(on_activation_failed);
		activation.activation_cancelled.connect(on_activation_cancelled);
		activation.activation_finished.connect(on_activation_finished);
		current_user = activation.get_user_info();
		if (current_user == null)
		{
			get_token();
		}
		else
			check_user();
	}
	
	~TiliadoAccountWidget()
	{
		activation.user_info_updated.disconnect(on_user_info_updated);
		activation.activation_started.disconnect(on_activation_started);
		activation.activation_failed.disconnect(on_activation_failed);
		activation.activation_cancelled.disconnect(on_activation_cancelled);
		activation.activation_finished.disconnect(on_activation_finished);
	}
	
	private void show_premium_required()
	{
		var label = new Gtk.Label(null);
		label.hexpand = true;
		label.set_markup(
			"<b>%s 4.x Rolling Releases require the <i>Premium</i> or <i>Patron</i> plan.</b>".printf(
				Nuvola.get_app_name()));
		label.wrap_mode = Pango.WrapMode.WORD_CHAR;
		label.set_line_wrap(true);
		label.show();
		attach(label, 0, 0, 2, 1);
	}
	
	private void get_token()
	{
		clear_all();
		show_premium_required();
		
		activate_button = new Gtk.Button.with_label("Activate " + Nuvola.get_app_name());
		activate_button.get_style_context().add_class("suggested-action");
		activate_button.hexpand = true;
		activate_button.halign = Gtk.Align.CENTER;
		activate_button.clicked.connect(on_activate_button_clicked);
		button_box.add(activate_button);
		
		plan_button = new Gtk.Button.with_label("Get a plan");
		plan_button.hexpand = true;
		plan_button.halign = Gtk.Align.CENTER;
		plan_button.clicked.connect(on_plan_button_clicked);
		button_box.add(plan_button);
		
		free_button = new Gtk.Button.with_label("Get Nuvola Player for free");
		free_button.hexpand = true;
		free_button.halign = Gtk.Align.CENTER;
		free_button.clicked.connect(on_free_button_clicked);
		button_box.add(free_button);
		
		button_box.hexpand = true;
		button_box.halign = Gtk.Align.CENTER;
		attach(button_box, 0, 1, 2, 1);
		show_all();
	}
	
	private void clear_status_row()
	{
		if (cancel_button != null)
		{
			cancel_button.clicked.disconnect(on_cancel_button_clicked);
			remove(cancel_button);
			cancel_button = null;
		}
		if (status_label != null)
		{
			remove(status_label);
			status_label = null;
		}
	}
	
	private void clear_all()
	{
		this.full_width = true;
		clear_status_row();
		if (plan_button != null)
		{
			plan_button.clicked.disconnect(on_plan_button_clicked);
			button_box.remove(plan_button);
			plan_button = null;
		}
		if (activate_button != null)
		{
			activate_button.clicked.disconnect(on_activate_button_clicked);
			button_box.remove(activate_button);
			activate_button = null;
		}
		if (free_button != null)
		{
			free_button.clicked.disconnect(on_free_button_clicked);
			button_box.remove(free_button);
			free_button = null;
		}
		if (logout_button != null)
		{
			logout_button.clicked.disconnect(on_logout_button_clicked);
			button_box.remove(logout_button);
			logout_button = null;
		}
		foreach (var child in get_children())
			remove(child);
	}
	
	private void on_activate_button_clicked(Gtk.Button button)
	{
		activate_button.sensitive = false;
		if (status_label != null)
			remove(status_label);
		
		status_label = new Gtk.Label("Authorization procedure in progress...");
		status_label.hexpand = true;
		status_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
		status_label.set_line_wrap(true);
		status_label.show();
		attach(status_label, 0, 3, 1, 1);
		
		cancel_button = new Gtk.Button.with_label("Cancel");
		cancel_button.hexpand = true;
		cancel_button.vexpand = false;
		cancel_button.halign = Gtk.Align.END;
		cancel_button.valign = Gtk.Align.CENTER;
		cancel_button.clicked.connect(on_cancel_button_clicked);
		cancel_button.show();
		attach(cancel_button, 1, 3, 1, 1);
		
		activation.start_activation();
	}
	
	private void on_free_button_clicked(Gtk.Button button)
	{
		app.show_uri("https://tiliado.github.io/nuvolaplayer/documentation/3.0/install.html");
	}
	
	private void on_plan_button_clicked(Gtk.Button button)
	{
		app.show_uri("https://tiliado.eu/nuvolaplayer/funding/");
	}
	
	private void on_cancel_button_clicked(Gtk.Button button)
	{
		activation.cancel_activation();
	}
	
	private void on_logout_button_clicked(Gtk.Button button)
	{
		activation.drop_activation();
		get_token();
	}
	
	private void on_activation_started(string uri)
	{
		if (activate_button != null && !activate_button.sensitive)
			app.show_uri(uri);
	}
	
	private void on_activation_failed(string message)
	{
		activate_button.sensitive = true;
		clear_status_row();
		status_label = new Gtk.Label(null);
		status_label.set_markup(Markup.printf_escaped("<b>Authorization failed:</b> %s", message));
		status_label.hexpand = true;
		status_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
		status_label.set_line_wrap(true);
		status_label.show();
		attach(status_label, 0, 3, 4, 1);
	}
	
	private void on_activation_cancelled()
	{
		activate_button.sensitive = true;
		clear_status_row();
	}
	
	private void on_activation_finished(TiliadoApi2.User? user)
	{
		this.current_user = user;
		check_user();
	}
	
	private void on_user_info_updated(TiliadoApi2.User? user)
	{
		this.current_user = user;
		check_user();
	}
	
	private void check_user()
	{
		var user = this.current_user;
		if (user == null)
		{
			get_token();
			return;
		}
		
		clear_all();
		logout_button = new Gtk.Button.from_icon_name("system-shutdown-symbolic", Gtk.IconSize.BUTTON);
		logout_button.hexpand = true;
		logout_button.vexpand = false;
		logout_button.halign = Gtk.Align.END;
		logout_button.valign = Gtk.Align.CENTER;
		logout_button.clicked.connect(on_logout_button_clicked);
		
		if (user.membership < TiliadoMembership.BASIC)
		{
			show_premium_required();
			plan_button = new Gtk.Button.with_label("Get Premium");
			plan_button.hexpand = false;
			plan_button.vexpand = false;
			plan_button.halign = Gtk.Align.END;
			plan_button.clicked.connect(on_plan_button_clicked);
			plan_button.get_style_context().add_class("premium");
			button_box.add(plan_button);
			
			free_button = new Gtk.Button.with_label("Get Nuvola for free");
			free_button.hexpand = false;
			free_button.vexpand = false;
			free_button.halign = Gtk.Align.END;
			free_button.clicked.connect(on_free_button_clicked);
			button_box.add(free_button);
			
			button_box.add(logout_button);
			
			button_box.halign = Gtk.Align.CENTER;
			attach(button_box, 0, 1, 2, 1);
		}
		else
		{
			var label = new Gtk.Label(user.name);
			label.max_width_chars = 15;
			label.ellipsize = Pango.EllipsizeMode.END;
			label.lines = 1;
			label.hexpand = label.vexpand = false;
			label.halign = Gtk.Align.END;
			label.show();
			label.margin_left = 	15;
			attach(label, 0, 1, 1, 1);
			
			var account_label = new AccountTypeLabel(TiliadoMembership.from_uint(user.membership));
			account_label.hexpand = false;
			account_label.vexpand = false;
			account_label.halign = Gtk.Align.END;
			account_label.show();
			attach(account_label, 1, 1, 1, 1);
			
			button_box.add(logout_button);
			button_box.halign = Gtk.Align.END;
			attach(button_box, 2, 1, 1, 1);
			this.full_width = false;
		}
		
		button_box.hexpand = true;
		button_box.vexpand = false;
		button_box.show_all();
	}
}


public class AccountTypeLabel : Gtk.Label
{
	public AccountTypeLabel(TiliadoMembership membership)
	{
		GLib.Object(
			label: membership.get_label(),
			halign: Gtk.Align.CENTER, valign: Gtk.Align.CENTER);
		
		if (membership >= TiliadoMembership.PREMIUM)
			get_style_context().add_class("premium");
	}
}


public class AccountTypeButton : Gtk.Button
{
	public AccountTypeButton(TiliadoMembership membership)
	{
		GLib.Object();
		var label = new Gtk.Label(membership.get_label());
		label.hexpand = true;
		label.halign = Gtk.Align.CENTER;
		label.show();
		add(label);
		if (membership >= TiliadoMembership.PREMIUM)
			get_style_context().add_class("premium");
	}
	
}

} // namespace Nuvola
