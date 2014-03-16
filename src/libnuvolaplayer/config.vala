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
	private Json.Node? root;
	
	public Config(File file)
	{
		this.file = file;
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
			return null;
		
		try
		{
			return Json.gvariant_deserialize(object.get_member(member_name), null);
		}
		catch (GLib.Error e)
		{
			warning("Failed to deserialize key '%s'. %s", key, e.message);
			return null;
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
	
	public bool get_bool(string key, bool default=false)
	{
		string? member_name;
		unowned Json.Object? object = get_parent_object(key, out member_name);
		if (object == null || !object.has_member(member_name))
			return default;
		
		var member = object.get_member(member_name);
		if (member.get_node_type() != Json.NodeType.VALUE || member.get_value_type() != typeof(bool))
			return default;
		
		return member.get_boolean();
	}
	
	public int64 get_int(string key, int64 default=0)
	{
		string? member_name;
		unowned Json.Object? object = get_parent_object(key, out member_name);
		if (object == null || !object.has_member(member_name))
			return default;
		
		var member = object.get_member(member_name);
		if (member.get_node_type() != Json.NodeType.VALUE || member.get_value_type() != typeof(int64))
			return default;
		
		return member.get_int();
	}
	
	public double get_double(string key, double default=0.0)
	{
		string? member_name;
		unowned Json.Object? object = get_parent_object(key, out member_name);
		if (object == null || !object.has_member(member_name))
			return default;
		
		var member = object.get_member(member_name);
		if (member.get_node_type() != Json.NodeType.VALUE || member.get_value_type() != typeof(double))
			return default;
		
		return member.get_double();
	}
	
	public string get_string(string key, string default="")
	{
		string? member_name;
		unowned Json.Object? object = get_parent_object(key, out member_name);
		if (object == null || !object.has_member(member_name))
			return default;
		
		var member = object.get_member(member_name);
		if (member.get_node_type() != Json.NodeType.VALUE || member.get_value_type() != typeof(string))
			return default;
		
		return member.get_string();
	}
	
	public void set_string(string key, string value)
	{
		string? member_name;
		unowned Json.Object? object = create_parent_object(key, out member_name);
		return_if_fail(object != null);
		object.set_string_member(member_name, value);
		config_changed(key);
	}
	
	public void set_int(string key, int64 value)
	{
		string? member_name;
		unowned Json.Object? object = create_parent_object(key, out member_name);
		return_if_fail(object != null);
		object.set_int_member(member_name, value);
		config_changed(key);
	}
	
	public void set_bool(string key, bool value)
	{
		string? member_name;
		unowned Json.Object? object = create_parent_object(key, out member_name);
		return_if_fail(object != null);
		object.set_boolean_member(member_name, value);
		config_changed(key);
	}
	
	public void set_double(string key, double value)
	{
		string? member_name;
		unowned Json.Object? object = create_parent_object(key, out member_name);
		return_if_fail(object != null);
		object.set_double_member(member_name, value);
		config_changed(key);
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
