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

namespace Nuvola
{

public class PasswordManager
{
	private const string SCHEMA_ID = "eu.tiliado.nuvola.LoginCretentials";
	private const string SCHEMA_APP_ID = "app-id";
	private const string SCHEMA_HOSTNAME = "hostname";
	private const string SCHEMA_USERNAME = "username";
	private string app_id;
	private Secret.Schema secret_schema;
	private HashTable<string, Diorite.SingleList<LoginCredentials>>? passwords = null;
	
	public PasswordManager(string app_id)
	{
		this.app_id = app_id;
		secret_schema = new Secret.Schema(
			SCHEMA_ID, Secret.SchemaFlags.NONE,
			SCHEMA_APP_ID, Secret.SchemaAttributeType.STRING,
			SCHEMA_HOSTNAME, Secret.SchemaAttributeType.STRING,
			SCHEMA_USERNAME, Secret.SchemaAttributeType.STRING);
	}
	
	~PasswordManager()
	{
		debug("~PasswordManager");
	}
	
	public HashTable<string, Diorite.SingleList<LoginCredentials>>? get_passwords()
	{
		return passwords;
	}
	
	public async void fetch_passwords() throws GLib.Error
	{
		var collection = yield Secret.Collection.for_alias(
			null, Secret.COLLECTION_DEFAULT, Secret.CollectionFlags.LOAD_ITEMS, null);
		HashTable<string,string> attributes = new HashTable<string,string>(str_hash, str_equal);
		attributes[SCHEMA_APP_ID] = app_id;
		var flags = Secret.SearchFlags.ALL|Secret.SearchFlags.UNLOCK|Secret.SearchFlags.LOAD_SECRETS;
		var items = yield collection.search(secret_schema, attributes, flags, null);
		var credentials = new HashTable<string, Diorite.SingleList<LoginCredentials>>(str_hash, str_equal);
		foreach (var item in items)
		{
			attributes = item.get_attributes();
			var hostname = attributes[SCHEMA_HOSTNAME];
			var username = attributes[SCHEMA_USERNAME];
			var password = item.get_secret().get_text();
			var entries = credentials[hostname];
			if (entries == null)
			{
				entries = new Diorite.SingleList<LoginCredentials>(LoginCredentials.username_equals);
				entries.prepend(new LoginCredentials(username, password));
				credentials[hostname] = entries;
			}
			else
			{
				var entry = new LoginCredentials(username, password);
				var index = entries.index(entry);
				if (index >= 0)
					entries[index] = entry;
				else
					entries.prepend(entry);
			}
		}
		this.passwords = credentials;
	}
	
	public async void store_password(string hostname, string username, string password, Cancellable? cancellable=null)
	{
		try
		{
			yield Secret.password_store(
				secret_schema, Secret.COLLECTION_DEFAULT, "Password for '%s' at %s".printf(username, hostname),
				password, cancellable, SCHEMA_APP_ID, app_id,  SCHEMA_HOSTNAME, hostname, SCHEMA_USERNAME, username);
		}
		catch (GLib.Error e)
		{
			warning("Failed to store password for '%s' at %s. %s".printf(username, hostname, e.message));
		}
	}
}

} // namespace Nuvola
