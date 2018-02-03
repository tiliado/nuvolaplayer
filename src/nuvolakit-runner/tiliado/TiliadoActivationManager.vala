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

public class TiliadoActivationManager : TiliadoActivationLocal {
    public const string ACTIVATION_STARTED = "/tiliado-activation/activation-started";
    public const string ACTIVATION_FAILED = "/tiliado-activation/activation-failed";
    public const string ACTIVATION_CANCELLED = "/tiliado-activation/activation-cancelled";
    public const string ACTIVATION_FINISHED = "/tiliado-activation/activation-finished";
    public const string USER_INFO_UPDATED = "/tiliado-activation/user-info-updated";


    public MasterBus bus {get; construct;}

    public TiliadoActivationManager(TiliadoApi2 tiliado, MasterBus bus, Config config) {
        GLib.Object(tiliado: tiliado, config: config, bus: bus);
    }

    construct {
        bus.api.add_method("/tiliado-activation/get-user-info", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_get_user_info, null);
        bus.api.add_method("/tiliado-activation/update-user-info", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_update_user_info, null);
        bus.api.add_method("/tiliado-activation/start-activation", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_start_activation, null);
        bus.api.add_method("/tiliado-activation/cancel-activation", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_cancel_activation, null);
        bus.api.add_method("/tiliado-activation/drop-activation", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_drop_activation, null);
        bus.api.add_method("/tiliado-activation/start_activation", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_start_activation, null);
        bus.api.add_notification(
            ACTIVATION_STARTED, Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE|Drt.RpcFlags.SUBSCRIBE, null);
        bus.api.add_notification(
            ACTIVATION_FAILED, Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE|Drt.RpcFlags.SUBSCRIBE, null);
        bus.api.add_notification(
            ACTIVATION_CANCELLED, Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE|Drt.RpcFlags.SUBSCRIBE, null);
        bus.api.add_notification(
            ACTIVATION_FINISHED, Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE|Drt.RpcFlags.SUBSCRIBE, null);
        bus.api.add_notification(
            USER_INFO_UPDATED, Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE|Drt.RpcFlags.SUBSCRIBE, null);
        activation_started.connect(on_activation_started);
        activation_failed.connect(on_activation_failed);
        activation_cancelled.connect(on_activation_cancelled);
        activation_finished.connect(on_activation_finished);
        user_info_updated.connect(on_user_info_updated);
    }

    ~TiliadoActivationManager() {
        activation_started.disconnect(on_activation_started);
        activation_failed.disconnect(on_activation_failed);
        activation_cancelled.disconnect(on_activation_cancelled);
        activation_finished.disconnect(on_activation_finished);
        user_info_updated.disconnect(on_user_info_updated);
    }

    private void handle_get_user_info(Drt.RpcRequest request) throws Drt.RpcError {
        TiliadoApi2.User? user = get_user_info();
        request.respond(user != null ? user.to_variant() : null);
    }

    private void handle_update_user_info(Drt.RpcRequest request) throws Drt.RpcError {
        update_user_info();
        request.respond(null);
    }

    private void handle_start_activation(Drt.RpcRequest request) throws Drt.RpcError {
        start_activation();
        request.respond(null);
    }

    private void handle_cancel_activation(Drt.RpcRequest request) throws Drt.RpcError {
        cancel_activation();
        request.respond(null);
    }

    private void handle_drop_activation(Drt.RpcRequest request) throws Drt.RpcError {
        drop_activation();
        request.respond(null);
    }

    private void on_activation_started(string url) {
        bus.api.emit(ACTIVATION_STARTED, null, new Variant.string(url));
    }

    private void on_activation_failed(string detail) {
        bus.api.emit(ACTIVATION_FAILED, null, detail);
    }

    private void on_activation_cancelled() {
        bus.api.emit(ACTIVATION_CANCELLED, null, null);
    }

    private void on_activation_finished(TiliadoApi2.User? user) {
        bus.api.emit(ACTIVATION_FINISHED, null, user == null ? null : user.to_variant());
    }

    private void on_user_info_updated(TiliadoApi2.User? user) {
        bus.api.emit(USER_INFO_UPDATED, null, user == null ? null : user.to_variant());
    }
}

} // namespace Nuvola
