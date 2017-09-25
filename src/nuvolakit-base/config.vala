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

namespace Nuvola
{

public class Config : GLib.Object, Drt.KeyValueStorage
{
	public Drt.Lst<Drt.PropertyBinding> property_bindings {get; protected set;}
	public File file {get; private set;}
	public HashTable<string, Variant> defaults {get; private set;}
	private Json.Node? root;
	private uint save_cb_id = 0;
	
	public Config(File file, HashTable<string, Variant>? defaults = null)
	{
		property_bindings = new Drt.Lst<Drt.PropertyBinding>();
		this.file = file;
		this.defaults = defaults != null ? defaults : new HashTable<string, Variant>(str_hash, str_equal);
		load();
		changed.connect(on_changed);
	}
	
	public signal void reloaded();
	
	public bool reload()
	{
		var result = load();
		reloaded();
		return result;
	}
	
	public bool owerwrite(string data)
	{
		var parser = new Json.Parser();
		unowned Json.Node? root;
		try
		{
			parser.load_from_data(data);
			root = parser.get_root();
		}
		catch (GLib.Error e)
		{
			root = null;
			debug("Json Error: %s", e.message);
		}
		
		if (root == null)
		{
			this.root = new Json.Node(Json.NodeType.OBJECT);
			this.root.set_object(new Json.Object());
			return false;
		}

		this.root = root.copy();
		return true;
	}
	
	public string to_string()
	{
		var generator = new Json.Generator();
		generator.root = root;
		generator.pretty = true;
		return generator.to_data(null);
	}
	
	public bool has_key(string key)
	{
		string? member_name;
		unowned Json.Object? object = get_parent_object(key, out member_name);
		return object != null && object.has_member(member_name);
	}
	
	public Variant? get_value(string key)
	{
		string? member_name;
		unowned Json.Object? object = get_parent_object(key, out member_name);
		if (object == null || !object.has_member(member_name))
			return defaults.get(key);
		
		try
		{
			return Json.gvariant_deserialize(object.get_member(member_name), null);
		}
		catch (GLib.Error e)
		{
			warning("Failed to deserialize key '%s'. %s", key, e.message);
			return defaults.get(key);
		}
	}
	
	protected void set_value_unboxed(string key, Variant? value)
	{
		string? member_name;
		unowned Json.Object? object = create_parent_object(key, out member_name);
		return_if_fail(object != null);
		Variant? old_value = null;
		if (object.has_member(member_name))
		{
			try
			{
				old_value = Json.gvariant_deserialize(object.get_member(member_name), null);
			}
			catch (GLib.Error e)
			{
				assert_not_reached();
			}
		}
		if (value == null)
		{
			if (object.has_member(member_name))
			{
				object.remove_member(member_name);
				changed(key, old_value);
			}
		}
		else
		{
			if (old_value == null || !old_value.equal(value))
			{
				var node = Json.gvariant_serialize(value);
				object.set_member(member_name, (owned) node);
				changed(key, old_value);
			}
		}
	}
	
	protected void set_default_value_unboxed(string key, Variant? value)
	{
		if (value == null)
			defaults.remove(key);
		else
			defaults.insert(key, value);
	}
	
	public void unset(string key)
	{
		set_value(key, null);
	}
	
	private bool load()
	{
		var parser = new Json.Parser();
		unowned Json.Node? root;
		try
		{
			parser.load_from_file(file.get_path());
			root = parser.get_root();
		}
		catch (GLib.Error e)
		{
			root = null;
			debug("Json Error: %s", e.message);
		}
		
		if (root == null)
		{
			this.root = new Json.Node(Json.NodeType.OBJECT);
			this.root.set_object(new Json.Object());
			return false;
		}
		this.root = root.copy();
		return true;
	}
	
	private unowned Json.Object? get_parent_object(string key, out string? member_name)
	{
		member_name = null;
		var keys = key.split(".");
		unowned Json.Node node = root;
		for (var i = 0; i < keys.length - 1; i++)
		{
			if (node.get_node_type() != Json.NodeType.OBJECT)
				return null;
			var object = node.get_object();
			var name = keys[i];
			if (!object.has_member(name))
				return null;
			node = object.get_member(name);
		}
		
		if (node.get_node_type() != Json.NodeType.OBJECT)
			return null;
		
		member_name = keys[keys.length - 1];
		return node.get_object();
	}
	
	private unowned Json.Object? create_parent_object(string key, out string? member_name)
	{
		member_name = null;
		var keys = key.split(".");
		unowned Json.Node node = root;
		for (var i = 0; i < keys.length - 1; i++)
		{
			if (node.get_node_type() != Json.NodeType.OBJECT)
				return null;
			var object = node.get_object();
			var name = keys[i];
			if (!object.has_member(name))
			{
				var new_node = new Json.Node(Json.NodeType.OBJECT);
				new_node.set_object(new Json.Object());
				object.set_member(name, new_node);
			}
			node = object.get_member(name);
		}
		
		if (node.get_node_type() != Json.NodeType.OBJECT)
			return null;
		
		member_name = keys[keys.length - 1];
		return node.get_object();
	}
	
	private void on_changed(string key, Variant? old_value)
	{
		if (save_cb_id != 0)
			Source.remove(save_cb_id);
		save_cb_id = Timeout.add(250, save_cb);
	}
	
	private bool save_cb()
	{
		save_cb_id = 0;
		var generator = new Json.Generator();
		generator.root = root;
		generator.pretty = true;
		try
		{
			file.get_parent().make_directory_with_parents();
		}
		catch (GLib.Error e)
		{
		}
		try
		{
			generator.to_file(file.get_path());
			message("Config saved to %s", file.get_path());
		}
		catch (GLib.Error e)
		{
			warning("Failed to save file %s. %s", file.get_path(), e.message);
		}
		return false;
	}
	
	public async bool has_key_async(string key) {
		yield Drt.EventLoop.resume_later();
		return has_key(key);
	}
	
	public async Variant? get_value_async(string key) {
		yield Drt.EventLoop.resume_later();
		return get_value(key);
	}
	
	public async void unset_async(string key) {
		unset(key);
		yield Drt.EventLoop.resume_later();
	}
	
	protected async void set_value_unboxed_async(string key, Variant? value) {
		set_value_unboxed(key, value);
		yield Drt.EventLoop.resume_later();
	}
	
	protected async void set_default_value_unboxed_async(string key, Variant? value) {
		set_default_value_unboxed(key, value);
		yield Drt.EventLoop.resume_later();
	}
}

} // namespace Nuvola
