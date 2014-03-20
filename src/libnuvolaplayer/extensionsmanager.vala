/*
 * Copyright 2012-2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace ConfigKey
{
	public const string EXTENSION_ENABLED = "extensions.%s.enabled";
}

/**
 * Extension Manager is responsible for loading and unloading extensions.
 * 
 * Extensions are currently kind of fake extensions, because they are included
 * in the main application binary (nuvolaplayer), but they will be build
 * as separate libraries (libnuvolaplayer-extensionid.so) in the future
 */
public class ExtensionsManager
{
	private WebAppController controller;
	private HashTable<string, Extension> active_extensions;
	public HashTable<string, ExtensionInfo?> available_extensions {get; private set;}
	
	/**
	 * Creates new Extensions Manager
	 * 
	 * @param ui_manager	main UI manager
	 * @param window		main application window
	 * @param objects		object container providing all necessary dependencies for extensions
	 */
	public ExtensionsManager(WebAppController controller)
	{
		this.controller = controller;
		active_extensions = new HashTable<string, Extension>(str_hash, str_equal);
		available_extensions = new HashTable<string, ExtensionInfo?>(str_hash, str_equal);
		find_extensions();
	}
	
	/**
	 * Returns extension by id
	 * 
	 * @param id extension id
	 * @return extension instance or null if not found
	 */
	public unowned Extension? get(string id)
	{
		return active_extensions.lookup(id);
	}
	
	/**
	 * Loads extension instance
	 * @param id id of the extension
	 * @return	extension or null if not found
	 */
	public unowned Extension? load(string id)
	{
		weak Extension? result = get(id);
		if (result != null)
			return result;
		
		ExtensionInfo? info = available_extensions.lookup(id);
		if (info != null)
		{
			var extension = Object.new(info.type, "id", id) as Extension;
			if (extension != null)
			{
				try
				{
					extension.load(controller);
					message("Extension with id '%s' loaded.", id);
				}
				catch (Error e)
				{
					warning("Unable to load extension '%s': %s", id, e.message);
					return null;
				}
				
				active_extensions.insert(id, extension);
				result = extension;
				return result;
			}
			
		}
		return null;
	}
	
	/**
	 * Uloads extension with id id
	 */
	public bool unload(string id)
	{
		var extension = get(id);
		if (extension != null)
		{
			extension.unload();
			active_extensions.remove(id);
			message("Extension with id '%s' unloaded.", id);
			return true;
		}
		return false;
	}
	
	/**
	 * Unloads all extensions.
	 */
	public void unload_all()
	{
		foreach (string extension in active_extensions.get_keys())
		{
			unload(extension);
		}
	}
	
	private void find_extensions()
	{
		// TODO: load extensions from libraries
		
		// Built-in extensions
		available_extensions.insert("sample", Nuvola.Extensions.Sample.get_info());
		available_extensions.insert("notifications", Nuvola.Extensions.Notifications.get_info());
		available_extensions.insert("trayicon", Nuvola.Extensions.TrayIcon.get_info());
		#if UNITY
		available_extensions.insert("unityquicklist", Nuvola.Extensions.UnityQuickList.get_info());
		#endif
	}
}

/**
 * Struct holding extension information
 */
public struct ExtensionInfo
{
	/**
	 * Human-readable name of the extension
	 */
	public string name;
	/**
	 * Version of the extension
	 */
	public string version;
	/**
	 * Description of the extension
	 */
	public string description;
	/**
	 * Author of the extension
	 */
	public string author;
	/**
	 * GLib type of the extension class
	 */
	public Type type;
	/**
	 * Load the extension automatically unless disabled.
	 */
	public bool autoload;
	
	/**
	 * Creates new struct with extension info
	 */
	public ExtensionInfo(string name, string description, string author, Type type, bool autoload=true)
	{
		this.name = name;
		this.description = description;
		this.author = author;
		this.type = type;
		this.autoload = autoload;
	}
}

/**
 * Errors related to extensions.
 */
public errordomain ExtensionError
{
	/**
	 * Extension fails to load
	 */
	EXTENSION_FAILURE;
}

} // namespace Nuvola
