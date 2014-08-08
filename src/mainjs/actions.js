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

/**
 * Manages actions
 * 
 * Actions can be shown in various user interface components such as menu, tray icon menu, Unity HUD, Unity Laucher
 * Quicklist, or invoked by keyboard shortcut, remote control, etc.
 * 
 * Some actions are provided by the Nuvola Player backend (e. g. @link{BrowserAction|browser actions}),
 * some are created by JavaScript API objects (e. g. @link{PlayerAction|media player actions}) and
 * web app integration scripts can create custom actions with @link{Actions.addAction} or @link{Actions.addRadioAction}.
 */
var Actions = $prototype(null, SignalsMixin);

/**
 * Initializes new Actions object
 */
Actions.$init = function()
{
    /**
     * Emitted when an action is activated.
     * 
     * @param String name    action name
     * 
     * ```
     * MyObject.$init = function()
     * {
     *     Nuvola.actions.connect("ActionActivated", this);
     * }
     * 
     * MyObject._onActionActivated = function(emitter, name)
     * {
     *     console.log("Action activated: " + name);
     * }
     * ```
     */
    this.addSignal("ActionActivated");
    
    /**
     * Emitted when an action has been enabled or disabled.
     * 
     * @param String name        action name
     * @param Boolean enabled    true if the action is enabled
     * 
     * ```
     * MyObject.$init = function()
     * {
     *     Nuvola.actions.connect("ActionEnabledChanged", this);
     * }
     * 
     * MyObject._ActionEnabledChanged = function(emitter, name, enabled)
     * {
     *     console.log("Action " + name + " " + (enabled ? "enabled" : "disabled") + ".");
     * }
     * ```
     */
    this.addSignal("ActionEnabledChanged");
    this.connect("ActionActivated", this);
    this.connect("ActionEnabledChanged", this);
    this.buttons = {};
}

/**
 * Adds new simple or toggle action.
 * 
 * when action is activated, signal ActionActivated is emitted.
 * 
 * @param String group               action group, e.g. "playback"
 * @param String scope               action scope, use "win" for window-specific actions (preferred) or "app" for
 *                                   app-specific actions
 * @param String name                action name, should be in ``dash-separated-lower-case``, e.g. ``toggle-play``
 * @param String|null label          label shown in user interface, e.g. ``Play``
 * @param String|null mnemo_label    label shown in user interface with keyboard navigation using Alt key and letter
 *                                   prefixed with underscore, e.g. Alt+p for ``_Play``
 * @param String|null icon           icon name for action
 * @param String|null keybinding     in-app keyboard shortcut, e.g. ``<ctrl>P``
 * @param Boolean|null state         ``null`` for simple actions, ``true``/``false`` for toggle actions (on/off)
 * 
 * ```
 * // Add new simple action ``play`` with icon ``media-playback-start``
 * Nuvola.actions.addAction("playback", "win", "play", "Play", null, "media-playback-start", null);
 * 
 * // Add new toggle action ``thumbs-up`` with initial state ``true`` (on)
 * Nuvola.actions.addAction("playback", "win", "thumbs-up", "Thumbs up", null, null, null, true);
 * ```
 */
Actions.addAction = function(group, scope, name, label, mnemo_label, icon, keybinding, state)
{
    var state = state !== undefined ? state: null;
    Nuvola._sendMessageSync("Nuvola.Actions.addAction", group, scope, name, label || "", mnemo_label || "", icon || "", keybinding || "", state);
}

/**
 * Adds new radio action (action with multiple states/option like old radios)
 * 
 * when action is activated, signal ActionActivated is emitted.
 * 
 * @param String group       action group, e.g. "playback"
 * @param String scope       action scope, use "win" for window-specific actions (preferred) or "app" for
 *                           app-specific actions
 * @param String name        action name, should be in ``dash-separated-lower-case``, e.g. ``toggle-play``
 * @param variant stateId    initial state of the action. must be one of states specified in ``options`` array
 * @param Array options      array of options definition in form ``[stateId, label, mnemo_label, icon, keybinding]``.
 *                           ``stateId`` is unique identifier (Number or String), other parameters are described
 *                           in ``addAction`` method.
 * 
 * ```
 * // define rating options - 5 states with state id 0-5 representing 0-5 stars
 * var ratingOptions = [
 *     // stateId, label, mnemo_label, icon, keybinding
 *     [0, "Rating: 0 stars", null, null, null, null],
 *     [1, "Rating: 1 star", null, null, null, null],
 *     [2, "Rating: 2 stars", null, null, null, null],
 *     [3, "Rating: 3 stars", null, null, null, null],
 *     [4, "Rating: 4 stars", null, null, null, null],
 *     [5, "Rating: 5 stars", null, null, null, null]
 * ];
 * 
 * // Add new radio action named ``rating`` with initial state ``0`` (0 stars)
 * Nuvola.actions.addRadioAction("playback", "win", "rating", 0, ratingOptions);
 * ``` 
 */
Actions.addRadioAction = function(group, scope, name, stateId, options)
{
    Nuvola._sendMessageSync("Nuvola.Actions.addRadioAction", group, scope, name, stateId, options);
}

Actions._onActionActivated = function(arg1, action)
{
    console.log("JS API: Action activated: " + action);
}

/**
 * Checks whether action is enabled
 * 
 * @param String name    action name
 * @return true is action is enabled, false otherwise
 */
Actions.isEnabled = function(name)
{
    return Nuvola._sendMessageSync("Nuvola.Actions.isEnabled", name);
}

/**
 * Sets whether action is enabled
 * 
 * @param String name        action name
 * @param Boolean enabled    true is action is enabled, false otherwise
 */
Actions.setEnabled = function(name, enabled)
{
    return Nuvola._sendMessageSync("Nuvola.Actions.setEnabled", name, enabled);
}

/**
 * Get current state of toggle or radio actions.
 * 
 * @param String name    action name
 * @return current state: ``true/false`` for toggle actions, one of stateId entries of radio actions
 * 
 * ```
 * var thumbsUp = Nuvola.actions.getState("thumbs-up");
 * console.log("Thumbs up is toggled " + (thumbsUp ? "on" : "off"));
 * 
 * var stars = Nuvola.actions.getState("rating");
 * console.log("Number of stars: " + stars);
 * ```
 */
Actions.getState = function(name)
{
    return Nuvola._sendMessageSync("Nuvola.Actions.getState", name);
}

/**
 * Set current state of toggle or radio actions.
 * 
 * @param String name      action name
 * @param variant state    current state: ``true/false`` for toggle actions, one of stateId entries of radio actions
 * 
 * ```
 * // toggle thumbs-up off
 * Nuvola.actions.setState("thumbs-up", false);
 * 
 * // Set 5 stars
 * Nuvola.actions.setState("rating", 5);
 * ```
 */
Actions.setState = function(name, state)
{
    return Nuvola._sendMessageSync("Nuvola.Actions.setState", name, state);
}

/**
 * Activate (invoke) action
 * 
 * @param String name    action name
 */
Actions.activate = function(name)
{
    Nuvola._sendMessageAsync("Nuvola.Actions.activate", name);
}


/**
 * Attach HTML button to an action
 * 
 * The button.disabled and action.enabled properties are synchronized and action is activated when button is clicked.
 * 
 * @param String name          action name
 * @param HTMLButton button    HTML button element
 * 
 * ```
 * var navigateBack = Nuvola.makeElement("button", null, "<");
 * var elm = document.getElementById("bar");
 * elm.appendChild(navigateBack);
 * Nuvola.actions.attachButton(Nuvola.BrowserAction.GO_BACK, navigateBack);
 * ```
 */
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

/**
 * Instance object of @link{Actions} prototype connected to Nuvola backend.
 */
Nuvola.actions = $object(Actions);
