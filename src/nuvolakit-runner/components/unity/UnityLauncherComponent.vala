/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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


namespace Nuvola {

public class UnityLauncherComponent: Component {
    #if UNITY
    private Bindings bindings;
    private Drtgtk.Application app;
    private UnityLauncher? launcher = null;
    #endif

    public UnityLauncherComponent(Drtgtk.Application app, Bindings bindings, Drt.KeyValueStorage config) {
        base(
            "unity_launcher", "Extra Dock Actions",
            "Adds extra actions to the menu of the application icon in Unity Launcher or elementaryOS dock.", "docks");
        #if UNITY
        this.bindings = bindings;
        this.app = app;
        config.bind_object_property("component.%s.".printf(id), this, "enabled").set_default(true).update_property();
        #else
        available = false;
        #endif
    }

    #if UNITY
    protected override bool activate() {
        launcher = new UnityLauncher(app, bindings.get_model<LauncherModel>());
        return true;
    }

    protected override bool deactivate() {
        launcher = null;
        return true;
    }
    #endif
}

} // namespace Nuvola
