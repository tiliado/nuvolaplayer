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

public class Config : GLib.Object, KeyValueStorage
{
	public File file {get; private set;}
	public HashTable<string, Variant> defaults {get; private set;}
	private Json.Node? root;
	
	
	public Config(File file, HashTable<string, Variant>? defaults = null)
	{
		this.file = file;
		this.defaults = defaults != null ? defaults : new HashTable<string, Variant>(str_hash, str_equal);
		load();
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
	
	public bool save() throws GLib.Error
	{
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
		
		generator.to_file(file.get_path());
		return true;
		
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
	
	public void set_value(string key, Variant? value)
	{
		string? member_name;
		unowned Json.Object? object = create_parent_object(key, out member_name);
		return_if_fail(object != null);
		if (value == null)
		{
			if (object.has_member(member_name))
			{
				object.remove_member(member_name);
				config_changed(key);
			}
		}
		else
		{
			var node = Json.gvariant_serialize(value);
			object.set_member(member_name, (owned) node);
			config_changed(key);
		}
	}
	
	public void set_default_value(string key, Variant? value)
	{
		if (value == null)
			defaults.remove(key);
		else
			defaults.insert(key, value);
	}
	
	public bool get_bool(string key)
	{
		var value = get_value(key);
		if (value != null && value.is_of_type(VariantType.BOOLEAN))
			return value.get_boolean();
		return false;
	}
	
	public int64 get_int(string key)
	{
		var value = get_value(key);
		if (value != null && value.is_of_type(VariantType.INT64))
			return value.get_int64();
		return (int64) 0;
	}
	
	public double get_double(string key)
	{
		var value = get_value(key);
		if (value != null && value.is_of_type(VariantType.DOUBLE))
			return value.get_double();
		return 0.0;
	}
	
	public string? get_string(string key)
	{
		var value = get_value(key);
		if (value != null && value.is_of_type(VariantType.STRING))
			return value.get_string();
		return null;
	}
	
	public void set_string(string key, string? value)
	{
		set_value(key, value != null ? new Variant.string(value) : null);
	}
	
	public void set_int(string key, int64 value)
	{
		set_value(key, new Variant.int64(value));
	}
	
	public void set_bool(string key, bool value)
	{
		set_value(key, new Variant.boolean(value));
	}
	
	public void set_double(string key, double value)
	{
		set_value(key, new Variant.double(value));
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
}

} // namespace Nuvola
