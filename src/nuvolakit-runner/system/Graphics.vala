/*
 * Copyright 2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola.Graphics
{

#if FLATPAK
public string? get_required_gl_extension()
{
	try
	{
		var nvidia_version = Diorite.System.read_file(File.new_for_path("/sys/module/nvidia/version")).strip();
		if (nvidia_version != "")
			return "nvidia-" + nvidia_version.replace(".", "-");
	}
	catch (GLib.Error e)
	{
		if (!(e is GLib.IOError.NOT_FOUND))
			error("Unexpected error: %s", e.message);
	}
	return null;
}

public bool is_required_gl_extension_mounted()
{
	var gl_extension = get_required_gl_extension();
	if (gl_extension == null)
		return true;
	else
		return File.new_for_path("/usr/lib/GL").get_child(gl_extension).query_exists();
}

public void ensure_gl_extension_mounted(Gtk.Window? parent_window)
{
	if (!is_required_gl_extension_mounted())
	{
		var gl_extension = get_required_gl_extension();
		var dialog = new Gtk.MessageDialog.with_markup(
			parent_window, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
			("<b><big>Missing Graphics Driver</big></b>\n\n"
			+ "Graphics driver '%s' for Flatpak has not been found on your system. "
			+ "Please consult <a href=\"https://github.com/tiliado/nuvolaruntime/wiki/Graphics-Drivers\">documentation "
			+ "on graphics drivers</a> to get help with installation."), gl_extension);
		Timeout.add_seconds(120, () => { dialog.destroy(); return false;});
		dialog.run();
		error("GL extension not found: %s", gl_extension);
	}
}
#endif

} // namespace Nuvola.Graphics
