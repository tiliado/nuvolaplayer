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

require("signals");

Nuvola.Actions =
{
	buttons: {},
	
	addAction: function(group, scope, name, label, mnemo_label, icon, keybinding, state)
	{
		var state = state !== undefined ? state: null;
		Nuvola._sendMessageSync("Nuvola.Actions.addAction", group, scope, name, label || "", mnemo_label || "", icon || "", keybinding || "", state);
	},
	
	addRadioAction: function(group, scope, name, state, options)
	{
		Nuvola._sendMessageSync("Nuvola.Actions.addRadioAction", group, scope, name, state, options);
	},
	
	debug: function(arg1, arg2)
	{
		console.log(arg1 + ", " + arg2);
	},
	
	isEnabled: function(name)
	{
		return Nuvola._sendMessageSync("Nuvola.Actions.isEnabled", name);
	},
	
	setEnabled: function(name, enabled)
	{
		return Nuvola._sendMessageSync("Nuvola.Actions.setEnabled", name, enabled);
	},
	
	getState: function(name)
	{
		return Nuvola._sendMessageSync("Nuvola.Actions.getState", name);
	},
	
	setState: function(name, state)
	{
		return Nuvola._sendMessageSync("Nuvola.Actions.setState", name, state);
	},
	
	activate: function(name)
	{
		Nuvola._sendMessageAsync("Nuvola.Actions.activate", name);
	},
	
	attachButton: function(name, button)
	{
		this.buttons[name] = button;
		button.disabled = !Nuvola.Actions.isEnabled(name);
		button.setAttribute("data-action-name", name);
		button.addEventListener('click', function()
		{
			Nuvola.Actions.activate(this.getAttribute("data-action-name"));
		});
	},
	
	onEnabledChanged: function(object, name, enabled)
	{
		if (this.buttons[name])
			this.buttons[name].disabled = !enabled;
	}
}

Nuvola.makeSignaling(Nuvola.Actions);
Nuvola.Actions.registerSignals(["action-activated", "enabled-changed"]);
Nuvola.Actions.connect("action-activated", Nuvola.Actions, "debug");
Nuvola.Actions.connect("enabled-changed", Nuvola.Actions, "onEnabledChanged");
