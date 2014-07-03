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

require("prototype");
require("signals");

var Actions = $prototype(null, SignalsMixin);

Actions.$init = function()
{
	this.registerSignals(["ActionActivated", "ActionEnabledChanged"]);
	this.connect("ActionActivated", this);
	this.connect("ActionEnabledChanged", this);
	this.buttons = {};
}

Actions.addAction = function(group, scope, name, label, mnemo_label, icon, keybinding, state)
{
	var state = state !== undefined ? state: null;
	Nuvola._sendMessageSync("Nuvola.Actions.addAction", group, scope, name, label || "", mnemo_label || "", icon || "", keybinding || "", state);
}

Actions.addRadioAction = function(group, scope, name, state, options)
{
	Nuvola._sendMessageSync("Nuvola.Actions.addRadioAction", group, scope, name, state, options);
}

Actions._onActionActivated = function(arg1, action)
{
	console.log("JS API: Action activated: " + action);
}

Actions.isEnabled = function(name)
{
	return Nuvola._sendMessageSync("Nuvola.Actions.isEnabled", name);
}

Actions.setEnabled = function(name, enabled)
{
	return Nuvola._sendMessageSync("Nuvola.Actions.setEnabled", name, enabled);
}

Actions.getState = function(name)
{
	return Nuvola._sendMessageSync("Nuvola.Actions.getState", name);
}

Actions.setState = function(name, state)
{
	return Nuvola._sendMessageSync("Nuvola.Actions.setState", name, state);
}

Actions.activate = function(name)
{
	Nuvola._sendMessageAsync("Nuvola.Actions.activate", name);
}

Actions.attachButton = function(name, button)
{
	this.buttons[name] = button;
	button.disabled = !this.isEnabled(name);
	button.setAttribute("data-action-name", name);
	
	var self = this;
	button.addEventListener('click', function()
	{
		self.activate(this.getAttribute("data-action-name"));
	});
}

Actions._onActionEnabledChanged = function(object, name, enabled)
{
	if (this.buttons[name])
		this.buttons[name].disabled = !enabled;
}

// export public items
Nuvola.Actions = Actions;
Nuvola.actions = $object(Actions);
