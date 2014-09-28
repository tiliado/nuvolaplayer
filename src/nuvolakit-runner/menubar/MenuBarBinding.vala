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

public class Nuvola.MenuBarBinding: Binding<MenuBarInterface>
{
	public MenuBarBinding(Diorite.Ipc.MessageServer server, WebWorker web_worker)
	{
		base(server, web_worker, "Nuvola.MenuBar");
		bind("setMenu", handle_menubar_set_menu);
	}
	
	private Variant? handle_menubar_set_menu(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(ssav)");
		string? id = null;
		string? label = null;
		int i = 0;
		VariantIter iter = null;
		data.get("(ssav)", &id, &label, &iter);
		return_val_if_fail(id != null && label != null && iter != null, null);
		string[] actions = new string[iter.n_children()];
		Variant item = null;
		while (iter.next("v", &item))
			actions[i++] = item.get_string();
		
		foreach (var object in objects)
			if (object.set_menu(id, label, actions))
				break;
		
		return null;
	}
}
