/*
 * Copyright 2016 Jiří Janoušek <janousek.jiri@gmail.com>
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
 
using WebKit.DOM;

namespace Nuvola
{

public class LoginForm: GLib.Object
{
	public WebKit.WebPage page {get; private set;}
	public HTMLFormElement form {get; private set;}
	public HTMLInputElement username {get; private set;}
	public HTMLInputElement password {get; private set;}
	public HTMLElement? submit {get; private set;}
	public Soup.URI uri {get; private set;}
	
	public LoginForm(WebKit.WebPage page, HTMLFormElement form, HTMLInputElement username, HTMLInputElement password,
		HTMLElement? submit)
	{
		this.page = page;
		this.form = form;
		this.username = username;
		this.password = password;
		this.submit = submit;
		this.uri = new Soup.URI(page.uri);
	}
	
	~LoginForm()
	{
	    debug("~LoginForm %s", uri.host);
	}
	
	public signal void new_credentials(string hostname, string username, string password);
	public signal void username_changed(string hostname, string? username);
	
	public void subscribe()
	{
		form.add_event_listener("submit", on_form_submitted, false);
		if (username != null) 
		    username.add_event_listener("blur", on_username_changed, false);
		if (submit != null)
			submit.add_event_listener("mousedown", on_form_submitted, false);
	}
	
	public void unsubscribe()
	{
	    form.remove_event_listener("submit", LoginForm.on_form_submitted, false);
	    if (submit != null)
			submit.remove_event_listener("mousedown", LoginForm.on_form_submitted, false);
	    if (username != null) 
			username.remove_event_listener("blur", LoginForm.on_username_changed, false);
	}
	
	public void fill(string? username, string? password, bool force)
	{
		var active_element = form.owner_document.active_element;
		if (this.username != null && username != null && username[0] != '\0' && (force || this.username != active_element))
			this.username.value = username;
		if (this.password != null && password != null && password[0] != '\0' && (force || this.password != active_element))
			this.password.value = password;
	}
	
	private void on_form_submitted(EventTarget target, Event event)
	{
		HTMLInputElement username; HTMLInputElement password; HTMLElement? submit;
		if (LoginFormManager.find_login_form_entries(form, out username, out password, out submit))
		{
			var username_value = username.value;
			var password_value = password.value;
			if (this.username != null)
			    this.username.remove_event_listener("blur", LoginForm.on_username_changed, false);
			this.username = username;
			if (username != null) 
			    username.add_event_listener("blur", on_username_changed, false);
			this.password = password;
			if (this.submit != null)
				this.username.remove_event_listener("mousedown", LoginForm.on_form_submitted, false);
			this.submit = submit;
			if (this.submit != null)
				this.username.add_event_listener("mousedown", on_form_submitted, false);
			if (username_value != null && password_value != null && username_value != "" && password_value != "")
				new_credentials(this.uri.host, username_value, password_value);
		}
		Timeout.add_seconds(5, refresh_cb);
	}
	
	private bool refresh_cb()
	{
		HTMLInputElement username; HTMLInputElement password; HTMLElement? submit;
		if (LoginFormManager.find_login_form_entries(form, out username, out password, out submit))
		{
			if (this.username != null)
			    this.username.remove_event_listener("blur", LoginForm.on_username_changed, false);
			this.username = username;
			if (username != null) 
			    username.add_event_listener("blur", on_username_changed, false);
			this.password = password;
			if (this.submit != null)
				this.username.remove_event_listener("mousedown", LoginForm.on_form_submitted, false);
			this.submit = submit;
			if (this.submit != null)
				this.username.add_event_listener("mousedown", on_form_submitted, false);
			username_changed(this.uri.host, username.value);
		}
		return true;
	}
	
	private void on_username_changed(EventTarget target, Event event)
	{
		username_changed(this.uri.host, username.value);
	}
}

} //namespace Nuvola
