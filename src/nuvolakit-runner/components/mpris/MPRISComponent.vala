/*
 * Copyright 2014-2016 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class MPRISComponent: Component
{
	private Bindings bindings;
	private Drt.Application app;
	private MPRISProvider? mpris = null;
	
	public MPRISComponent(Drt.Application app, Bindings bindings, Drt.KeyValueStorage config)
	{
		base("mpris", "MPRIS 2", "Remote media player interface used by Unity sound indicator and similar applets.");
		this.bindings = bindings;
		this.app = app;
		config.bind_object_property("component.mpris.", this, "enabled").set_default(true).update_property();
		enabled_set = true;
		auto_activate = false;
		if (enabled)
			load();
	}
	
	protected override bool activate()
	{
		mpris = new MPRISProvider(app, bindings.get_model<MediaPlayerModel>());
		mpris.start();
		return true;
	}
	
	protected override bool deactivate()
	{
		mpris.stop();
		mpris = null;
		return true;
	}
}

} // namespace Nuvola
