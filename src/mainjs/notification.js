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

/**
 * Desktop notification.
 */
var NotificationPrototype = $prototype(null);

/**
 * Creates new named notification.
 * 
 * @param String  name        notification name (identifier)
 * @param Boolean resident    mark the notification as resident by default
 */
NotificationPrototype.$init = function(name, resident)
{
	this.name = name;
	this.resident = !!resident;
}

/**
 * Update properties of a notification
 * 
 * @param String title        short title
 * @param String text         text of the notification
 * @param String? iconName    name of icon for notification
 * @param String? iconPath    path to an icon for notification
 * @param Boolean resident    mark the notification as resident, use null/undefined to reuse last value
 */
NotificationPrototype.update = function(title, text, iconName, iconPath, resident)
{
	if (resident == null)
		resident = this.resident;
	else
		this.resident = !!resident;
	
	Nuvola._sendMessageAsync("Nuvola.Notification.update", this.name, title, text, iconName || "", iconPath || "", !!resident);
}

/**
 * Set actions available as buttons in notification.
 * 
 * @param String[] actions    array of action names
 */
NotificationPrototype.setActions = function(actions)
{
	Nuvola._sendMessageAsync("Nuvola.Notification.setActions", this.name, actions);
}

/**
 * Remove all actions available as buttons in notification.
 */
NotificationPrototype.removeActions = function()
{
	Nuvola._sendMessageAsync("Nuvola.Notification.removeActions", this.name);
}

/**
 * Shows notification.
 * 
 * @param force    ensure notification is shown if true, otherwise show it when suitable
 */
NotificationPrototype.show = function(force)
{
	Nuvola._sendMessageAsync("Nuvola.Notification.show", this.name, !!force);
}

/**
 * Manages desktop notifications.
 */
var NotificationsPrototype = $prototype(null);

/**
 * Convenience method to creates new named notification.
 */
NotificationsPrototype.getNamedNotification = function(name)
{
	return $object(NotificationPrototype, name);
}

// export public items
Nuvola.NotificationPrototype = NotificationPrototype;
Nuvola.NotificationsPrototype = NotificationsPrototype;
Nuvola.Notifications = $object(NotificationsPrototype);
