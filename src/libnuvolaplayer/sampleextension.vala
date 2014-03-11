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

namespace Nuvola.Extensions.Sample
{

public Nuvola.ExtensionInfo get_info()
{
	return
	{
		/// Name of a sample plugin
		_("Sample plugin"),
		"2.7182818284...",
		/// Sample plugin descriptiom
		_("<p>This plugin is a sample.</p>"),
		"Jiří Janoušek",
		typeof(Extension),
		true
	};
}


/**
 * Simple sample plugin
 */
public class Extension : Nuvola.Extension
{
	private weak WebAppController controller;
	private Gtk.Label? label;
	
	/**
	 * {@inheritDoc}
	 */
	public override void load(WebAppController controller) throws ExtensionError
	{
		debug("[%s] load", id);
		this.controller = controller;
		label = new Gtk.Label("Hello!");
		label.show();
		controller.main_window.grid.add(label);
	}
	
	/**
	 * {@inheritDoc}
	 */
	public override void unload()
	{
		debug("[%s] unload", id);
		if (label != null)
		{
			controller.main_window.grid.remove(label);
			label = null;
		}
		
	}
}

} // namespace Nuvola.Extensions.Sample

