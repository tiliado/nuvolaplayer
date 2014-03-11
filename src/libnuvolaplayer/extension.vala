/*
 * Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

/**
 * Base Extension class
 */
public abstract class Nuvola.Extension : GLib.Object
{
	[Description(nick = "Id", blurb = "Extension id assigned by extensions manager.")]
	public string id {get; construct;}
	
	[Description(nick = "Preferences", blurb = "Whether the extension has preferences.")]
	public bool has_preferences {get; protected set; default = false;}
	
	#if DEBUG_MEMORY
	construct
	{
		debug("new Extension: %s", id);
	}
	#endif
	
	/**
	 * Loads the extension
	 * 
	 * @param objects			container providing dependencies
	 * @throw ExtensionError	when extension fails to load
	 */
	public abstract void load(WebAppController controller) throws ExtensionError;
	
	/**
	 * Unloads the extension
	 */
	public abstract void unload();
	
	/**
	 * Widget with preferences
	 * 
	 * @return widget containing preferences
	 */
	public virtual Gtk.Widget? get_preferences()
	{
		return null;
	}
	
	#if DEBUG_MEMORY
	~Extension()
	{
		debug("~Extension: %s", id);
	}
	#endif
}
