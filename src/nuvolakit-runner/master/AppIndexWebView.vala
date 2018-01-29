/*
 * Copyright 2017-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class AppIndexWebView : WebView {
    private unowned Drtgtk.Application app;
    private string? root_uri = null;

    public AppIndexWebView(Drtgtk.Application app, WebKit.WebContext context) {
        base(context);
        this.app = app;
        decide_policy.connect(on_decide_policy);
        zoom_level = 0.90;
        hexpand = vexpand = true;
    }

    public void load_app_index(string index_uri, string? root_uri=null) {
        this.root_uri = root_uri ?? index_uri;
        load_uri(index_uri);
    }

    private bool on_decide_policy(WebKit.PolicyDecision decision, WebKit.PolicyDecisionType decision_type) {
        switch (decision_type) {
        case WebKit.PolicyDecisionType.NAVIGATION_ACTION:
            return decide_navigation_policy(false, (WebKit.NavigationPolicyDecision) decision);
        case WebKit.PolicyDecisionType.NEW_WINDOW_ACTION:
            return decide_navigation_policy(true, (WebKit.NavigationPolicyDecision) decision);
        case WebKit.PolicyDecisionType.RESPONSE:
        default:
            return false;
        }
    }

    private bool decide_navigation_policy(bool new_window, WebKit.NavigationPolicyDecision decision) {
        WebKit.NavigationAction action = decision.navigation_action;
        WebKit.NavigationType type = action.get_navigation_type();
        bool user_gesture = action.is_user_gesture();
        // We care only about user clicks
        if (type != WebKit.NavigationType.LINK_CLICKED && !user_gesture) {
            return false;
        }

        string uri = action.get_request().uri;
        bool result = uri.has_prefix(root_uri) && !uri.has_suffix(".flatpakref");
        debug("Navigation, %s window: uri = %s, result = %s, frame = %s, type = %s, user gesture %s",
            new_window ? "new" : "current", uri, result.to_string(), decision.frame_name, type.to_string(),
            user_gesture.to_string());

        if (result) {
            if (new_window) {
                // Open in current window instead of a new window
                decision.ignore();
                Idle.add(() => {load_uri(uri); return false;});
                return true;
            }
            decision.use();
            return true;
        } else {
            app.show_uri(uri);
            decision.ignore();
            return true;
        }
    }
}

} // namespace Nuvola
