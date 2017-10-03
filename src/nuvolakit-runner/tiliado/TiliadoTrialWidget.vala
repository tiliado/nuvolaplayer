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

namespace Nuvola
{

public class TiliadoTrialWidget : Gtk.Grid {
	private Gtk.Button? purchase_button = null;
	private Gtk.Button? free_button = null;
	private TiliadoApi2.User? current_user = null;
	private Drtgtk.Application app;
	TiliadoMembership required_membership;
	TiliadoActivation activation;
	private Gtk.Popover? popover = null;
	private Gtk.Stack? stack = null;
	private View? get_plan_view;
	private View? get_account_view;
	private View? activate_view;
	private View? progress_view;
	private View? failed_view;
	private View? explore_view;
	
	public TiliadoTrialWidget(TiliadoActivation activation, Drtgtk.Application app,
			TiliadoMembership required_membership) {
		this.required_membership = required_membership;
		this.activation = activation;
		this.app = app;
		no_show_all = true;
		margin = 5;
		row_spacing = column_spacing = 5;
		orientation = Gtk.Orientation.HORIZONTAL;
		hexpand = true;
		vexpand = false;
		halign = Gtk.Align.FILL;
		activation.user_info_updated.connect(on_user_info_updated);
		activation.activation_started.connect(on_activation_started);
		activation.activation_failed.connect(on_activation_failed);
		activation.activation_cancelled.connect(on_activation_cancelled);
		activation.activation_finished.connect(on_activation_finished);
		current_user = activation.get_user_info();
		no_show_all = true;
		toggle_trial();
	}
	
	~TiliadoTrialWidget() {
		activation.user_info_updated.disconnect(on_user_info_updated);
		activation.activation_started.disconnect(on_activation_started);
		activation.activation_failed.disconnect(on_activation_failed);
		activation.activation_cancelled.disconnect(on_activation_cancelled);
		activation.activation_finished.disconnect(on_activation_finished);
	}
	
	private bool check_user() {
		var user = this.current_user;
		return user != null  && activation.has_user_membership(required_membership);
	}
	
	private void toggle_trial() {
		if (!check_user()) {
			if (purchase_button == null) {
				var label = Drtgtk.Labels.markup("<b>%s free trial</b>", Nuvola.get_app_name());
				label.halign = Gtk.Align.CENTER;
				label.hexpand = true;
				label.vexpand = true;
				label.show();
				add(label);
				purchase_button = new Gtk.Button.with_label("Purchase Nuvola");
				purchase_button.clicked.connect(on_purchase_button_clicked);
				add_button(purchase_button, "suggested-action");
				free_button = new Gtk.Button.with_label("Get Nuvola for free");
				free_button.clicked.connect(on_free_button_clicked);
				add_button(free_button);
			}
			show();
		} else if (popover == null || !popover.visible){
			clear_all();
			hide();
		}	
	}
	
	private void show_user_info() {
		if (current_user != null ) {
			var label = Drtgtk.Labels.markup("<b>User:</b> %s\n<b>Account:</b> %s",
				current_user.name, TiliadoMembership.from_uint(current_user.membership).get_label());
			label.halign = Gtk.Align.CENTER;
			label.hexpand = true;
			label.vexpand = true;
			label.margin_bottom = 10;
			add(label);
		}
	}
	
	private void clear_all() {
		if (purchase_button != null) {
			purchase_button.clicked.disconnect(on_purchase_button_clicked);
			remove(purchase_button);
			purchase_button = null;
		}
		if (free_button != null) {
			free_button.clicked.disconnect(on_free_button_clicked);
			remove(free_button);
			free_button = null;
		}
		foreach (var child in get_children()) {
			remove(child);
		}
		if (popover != null) {
			destroy_popover();
		}
	}
	
	private void add_button(Gtk.Button button, string? style_class=null) {
		button.hexpand = false;
		button.vexpand = true;
		button.halign = Gtk.Align.CENTER;
		button.valign = Gtk.Align.END;
		if (style_class != null) {
			button.get_style_context().add_class(style_class);
		}
		button.show();
		add(button);
	}
	
	private void on_purchase_button_clicked(Gtk.Button button) {
		if (popover == null) {
			create_popover();
		}
		popover.show_all();
	}
	
	private void create_popover() {
		popover = new Gtk.Popover(purchase_button);
		popover.position = Gtk.PositionType.TOP;
		stack = new Gtk.Stack();
		stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
		get_plan_view = new View(
			"Later", "I already have a plan", "Get a plan",
			Drtgtk.Labels.markup("""Choose a suitable Nuvola plan to get continuous updates and user support."""));
		get_plan_view.forward_button.clicked.connect(on_get_plan_forward_clicked);
		get_plan_view.back_button.clicked.connect(on_get_plan_back_clicked);
		get_plan_view.action_button.clicked.connect(on_get_plan_action_clicked);
		get_plan_view.help_button.clicked.connect(on_help_clicked);
		stack.add(get_plan_view);
		
		get_account_view = new View("Back", "I already have Tiliado account", "Get Tiliado account",
			Drtgtk.Labels.markup("""Create a Tiliado account which will be linked with Nuvola to verify your membership."""));
		get_account_view.forward_button.clicked.connect(on_get_account_forward_clicked);
		get_account_view.back_button.clicked.connect(on_get_account_back_clicked);
		get_account_view.action_button.clicked.connect(on_get_account_action_clicked);
		get_account_view.help_button.clicked.connect(on_help_clicked);
		stack.add(get_account_view);
		
		activate_view = new View("Later", null, "Activate Nuvola", Drtgtk.Labels.markup("""Nuvola developer will contact you on Patreon within two business days to activate your plan.

Once your plan is confirmed, you can activate Nuvola with the button bellow."""));
		activate_view.action_button.clicked.connect(on_activate_action_clicked);
		activate_view.back_button.clicked.connect(on_activate_back_clicked);
		activate_view.help_button.clicked.connect(on_help_clicked);
		stack.add(activate_view);
		
		progress_view = new View("Cancel", null, null, Drtgtk.Labels.markup("Activation is in progress. Follow instructions in your web browser."));
		progress_view.back_button.clicked.connect(on_progress_back_clicked);
		progress_view.help_button.clicked.connect(on_help_clicked);
		stack.add(progress_view);
		
		failed_view = new View("Cancel", null, "Try again", Drtgtk.Labels.markup(""));
		failed_view.back_button.clicked.connect(on_failed_back_clicked);
		failed_view.action_button.clicked.connect(on_failed_action_clicked);
		failed_view.help_button.clicked.connect(on_help_clicked);
		stack.add(failed_view);
		
		explore_view = new View("Close", null, "Explore Nuvola features", Drtgtk.Labels.markup(
		"""<b>Thank you for purchasing Nuvola.</b>

We recommend taking a look at a list of Nuvola features to get the most of it."""), false);
		explore_view.back_button.clicked.connect(on_explore_back_clicked);
		explore_view.action_button.clicked.connect(on_explore_action_clicked);
		stack.add(explore_view);
		
		stack.expand = false;
		stack.halign = Gtk.Align.FILL;
		popover.add(stack);
		popover.notify["visible"].connect_after(on_popover_visible_changed);
	}
	
	private void destroy_popover() {
		if (popover == null) {
			return;
		}
		get_plan_view.forward_button.clicked.disconnect(on_get_plan_forward_clicked);
		get_plan_view.back_button.clicked.disconnect(on_get_plan_back_clicked);
		get_plan_view.action_button.clicked.disconnect(on_get_plan_action_clicked);
		get_plan_view.help_button.clicked.disconnect(on_help_clicked);
		get_plan_view = null;
		get_account_view.forward_button.clicked.disconnect(on_get_account_forward_clicked);
		get_account_view.back_button.clicked.disconnect(on_get_account_back_clicked);
		get_account_view.action_button.clicked.disconnect(on_get_account_action_clicked);
		get_account_view.help_button.clicked.disconnect(on_help_clicked);
		get_account_view = null;
		activate_view.action_button.clicked.disconnect(on_activate_action_clicked);
		activate_view.back_button.clicked.disconnect(on_activate_back_clicked);
		activate_view.help_button.clicked.disconnect(on_help_clicked);
		activate_view = null;
		progress_view.back_button.clicked.disconnect(on_progress_back_clicked);
		progress_view.help_button.clicked.connect(on_help_clicked);
		progress_view = null;
		failed_view.action_button.clicked.disconnect(on_failed_action_clicked);
		failed_view.back_button.clicked.disconnect(on_failed_back_clicked);
		failed_view.help_button.clicked.disconnect(on_help_clicked);
		failed_view = null;
		explore_view.action_button.clicked.disconnect(on_explore_action_clicked);
		explore_view.back_button.clicked.disconnect(on_explore_back_clicked);
		explore_view = null;
		stack = null;
		popover.hide();
		popover.notify["visible"].disconnect(on_popover_visible_changed);
		popover.destroy();
		popover = null;
	}
	
	private void on_help_clicked(Gtk.Button button) {
		app.show_uri("https://tiliado.github.io/nuvolaplayer/documentation/4/activation.html");
	}
	
	private void on_get_plan_forward_clicked(Gtk.Button button) {
		stack.visible_child = get_account_view;
	}
	
	private void on_get_plan_back_clicked(Gtk.Button button) {
		destroy_popover();
	}
	
	private void on_get_plan_action_clicked(Gtk.Button button) {
		app.show_uri("https://tiliado.eu/nuvolaplayer/funding/");
	}
	
	private void on_get_account_forward_clicked(Gtk.Button button) {
		stack.visible_child = activate_view;
	}
	
	private void on_get_account_back_clicked(Gtk.Button button) {
		stack.visible_child = get_plan_view;
	}
	
	private void on_get_account_action_clicked(Gtk.Button button) {
		app.show_uri("https://tiliado.eu/accounts/signup/?next=/");
	}
	
	private void on_activate_action_clicked(Gtk.Button button) {
		stack.visible_child = progress_view;
		activation.start_activation();
	}
	
	private void on_activate_back_clicked(Gtk.Button button) {
		destroy_popover();
	}
	
	private void on_failed_action_clicked(Gtk.Button button) {
		stack.visible_child = progress_view;
		activation.start_activation();
	}
	
	private void on_failed_back_clicked(Gtk.Button button) {
		stack.visible_child = activate_view;
	}
	
	private void on_explore_action_clicked(Gtk.Button button) {
		app.show_uri("https://tiliado.github.io/nuvolaplayer/documentation/4.html");
	}
	
	private void on_explore_back_clicked(Gtk.Button button) {
		popover.hide();
	}
	
	private void on_progress_back_clicked(Gtk.Button button) {
		stack.visible_child = activate_view;
		activation.cancel_activation();
	}
	
	private void on_free_button_clicked(Gtk.Button button) {
		app.show_uri("https://github.com/tiliado/nuvolaruntime/wiki/Get-Nuvola-for-Free");
	}
	
	private void on_activation_started(string uri) {
		if (popover != null && popover.visible) {
			app.show_uri(uri);
		}
	}
	
	private void on_activation_failed(string message) {
		if (failed_view != null) {
			failed_view.text_label.set_markup(Markup.printf_escaped("<b>Authorization failed:</b>\n\n%s", message));
			stack.visible_child = failed_view;
		}
		toggle_trial();
	}
	
	private void on_activation_cancelled() {
		toggle_trial();
	}
	
	private void on_activation_finished(TiliadoApi2.User? user) {
		this.current_user = user;
		if (!check_user()) {
			if (failed_view != null && user != null) {
				failed_view.text_label.set_markup(Markup.printf_escaped(
				"""Your Tiliado account is valid but there is no record of purchased Nuvola plan.

<b>User:</b> %s
<b>Account:</b> %s""", user.name, TiliadoMembership.from_uint(user.membership).get_label()));
				stack.visible_child = failed_view;
			}
		} else if (stack != null) {
			stack.visible_child = explore_view;
		}
		toggle_trial();
	}
	
	private void on_user_info_updated(TiliadoApi2.User? user) {
		this.current_user = user;
		toggle_trial();
	}
	
	private void on_popover_visible_changed(GLib.Object o, ParamSpec p) {
		toggle_trial();
	}
	
	private class View: Gtk.Grid {
		public Gtk.Button? back_button = null;
		public Gtk.Button? forward_button = null;
		public Gtk.Button? action_button = null;
		public Gtk.Button? help_button = null;
		public Gtk.Label? text_label = null;
		
		public View(string? back_label, string? forward_label, string? action_label, Gtk.Label? text_label,
			bool help=true) {
			hexpand = false;
			halign = Gtk.Align.FILL;
			margin = 20;
			column_spacing = row_spacing = 10;
			orientation = Gtk.Orientation.VERTICAL;
			if (text_label != null) {
				this.text_label = text_label;
				text_label.max_width_chars = 30;
				text_label.justify = Gtk.Justification.FILL;
				attach(text_label, 0, 0, 1, 1);
			}
			if (action_label != null) {
				action_button = new Gtk.Button.with_label(action_label);
				action_button.vexpand = false;
				action_button.hexpand = true;
				action_button.halign = Gtk.Align.FILL;
				action_button.get_style_context().add_class("suggested-action");
				attach(action_button, 0, 8, 1, 1);
			}
			if (back_label != null) {
				back_button = new Gtk.Button.with_label(back_label);
				back_button.vexpand = false;
				back_button.hexpand = true;
				back_button.halign = Gtk.Align.START;
				attach(back_button, 0, 11, 1, 1);
				back_button.halign = Gtk.Align.FILL;
			}
			if (forward_label != null) {
				forward_button = new Gtk.Button.with_label(forward_label);
				forward_button.vexpand = false;
				forward_button.hexpand = true;
				attach(forward_button, 0, 9, 1, 1);
				forward_button.halign = Gtk.Align.FILL;
			}
			if (help) {
				help_button = new Gtk.Button.with_label("Help");
				help_button.vexpand = false;
				help_button.hexpand = true;
				attach(help_button, 0, 10, 1, 1);
				help_button.halign = Gtk.Align.FILL;
			}
			
			var first_button = action_button ?? forward_button ?? help_button ?? back_button;
			if (first_button != null) {
				first_button.vexpand = true;
				first_button.valign = Gtk.Align.END;
				first_button.margin_top = 20;
			}
		}		
	}
}

} // namespace Nuvola
