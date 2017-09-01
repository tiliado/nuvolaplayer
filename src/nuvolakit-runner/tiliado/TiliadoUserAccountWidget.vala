/*
 * Copyright 2016-2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola {

public class TiliadoUserAccountWidget : Gtk.Grid {
	private Gtk.Button? logout_button = null;
	private TiliadoActivation activation;
	private TiliadoApi2.User? current_user = null;
	
	public TiliadoUserAccountWidget(TiliadoActivation activation) {
		this.activation = activation;
		margin = 5;
		margin_left = margin_right = 10;
		row_spacing = column_spacing = 5;
		no_show_all = true;
		activation.user_info_updated.connect(on_user_info_updated);
		current_user = activation.get_user_info();
		check_user();
	}
	
	~TiliadoUserAccountWidget() {
		activation.user_info_updated.disconnect(on_user_info_updated);
	}
	
	private void clear_all() {
		if (logout_button != null) {
			logout_button.clicked.disconnect(on_logout_button_clicked);
			remove(logout_button);
			logout_button = null;
		}
		foreach (var child in get_children()) {
			remove(child);
		}
	}
	
	private void on_logout_button_clicked(Gtk.Button button) {
		activation.drop_activation();
	}
	
	private void on_user_info_updated(TiliadoApi2.User? user) {
		this.current_user = user;
		check_user();
	}
	
	private void check_user() {
		clear_all();
		var user = this.current_user;
		if (user != null) {
			var label = new Gtk.Label(user.name);
			label.max_width_chars = 15;
			label.ellipsize = Pango.EllipsizeMode.END;
			label.lines = 1;
			label.hexpand = label.vexpand = false;
			label.halign = Gtk.Align.END;
			label.show();
			label.margin_left = 15;
			attach(label, 0, 1, 1, 1);
			
			var account_label = new AccountTypeLabel(TiliadoMembership.from_uint(user.membership));
			account_label.hexpand = false;
			account_label.vexpand = false;
			account_label.halign = Gtk.Align.END;
			account_label.show();
			attach(account_label, 1, 1, 1, 1);
			
			logout_button = new Gtk.Button.from_icon_name("system-shutdown-symbolic", Gtk.IconSize.BUTTON);
			logout_button.hexpand = true;
			logout_button.vexpand = false;
			logout_button.halign = Gtk.Align.END;
			logout_button.valign = Gtk.Align.CENTER;
			logout_button.clicked.connect(on_logout_button_clicked);
			logout_button.show();
			attach(logout_button, 2, 1, 1, 1);
			
			show();
		} else {
			hide();
		}
	}
}

} // namespace Nuvola
