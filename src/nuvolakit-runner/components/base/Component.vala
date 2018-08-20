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

/**
 * Component classes represent a particular component/feature.
 */
public abstract class Component: GLib.Object {
    public string id {get; construct;}
    public string name {get; construct;}
    public string description {get; construct;}
    public string? help_url {get; construct;}
    public bool hidden {get; protected set; default = false;}
    public bool enabled {get; protected set; default = false;}
    public bool loaded {get; protected set; default = false;}
    public bool active {get; protected set; default = false;}
    public bool auto_activate {get; protected set; default = true;}
    public bool has_settings {get; protected set; default = false;}
    public bool available {get; protected set; default = true;}
    public TiliadoMembership required_membership {get; protected set; default = TiliadoMembership.NONE;}

    public Component(string id, string name, string description, string? help_page) {
        GLib.Object(
            id: id, name: name, description: description,
            help_url: create_help_url(help_page));
    }

    public bool is_membership_ok(TiliadoActivation? activation) {
        return (required_membership == TiliadoMembership.NONE
        || activation == null || activation.has_user_membership(required_membership));
    }

    public virtual void toggle(bool enabled) {
        if (enabled) {
            if (available) {
                if (this.enabled != enabled) {
                    this.enabled = true;
                }
                if (!loaded) {
                    message("Load %s %s", id, name);
                    load();
                    loaded = true;
                }
            }
        } else {
            if (loaded) {
                message("Unload %s %s", id, name);
                unload();
                loaded = false;
            }
            if (this.enabled != enabled) {
                this.enabled = false;
            }
            this.active = false;
        }
    }

    public virtual Gtk.Widget? get_settings() {
        return null;
    }

    public virtual string? get_unavailability_reason() {
        return null;
    }

    public virtual Gtk.Widget? get_unavailability_widget() {
        return null;
    }

    public virtual void auto_load() {
        toggle(enabled);
    }

    protected virtual void load() {
        if (auto_activate) {
            toggle_active(true);
        }
    }

    protected virtual void unload() {
        toggle_active(false);
    }

    public bool toggle_active(bool active) {
        if (!available || !enabled) {
            return false;
        }
        bool result = false;
        if (this.active != active) {
            message("%s: %s %s", active ? "Activate" : "Deactivate", id, name);
            result = active ? activate() : deactivate();
            if (!result) {
                warning("Failed to %s: %s %s", active ? "activate" : "deactivate", id, name);
            }
        }
        if (result) {
            this.active = active;
        }
        return result;
    }

    protected virtual bool activate() {
        return false;
    }

    protected virtual bool deactivate() {
        return false;
    }
}

} // namespace Nuvola
