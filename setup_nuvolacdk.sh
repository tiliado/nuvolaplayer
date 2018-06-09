if [ -z "$DIORITE_PATH" ]; then DIORITE_PATH="$1"; fi

if [ -z "$DIORITE_PATH" -o ! -d "$DIORITE_PATH" ]; then
    echo "Error: Specify the path to the Diorite library repository checkout as the first argument"
else
    WAF_CONFIGURE=" --webkitgtk-supports-mse --branding=cdk "
    . setup_env.sh
    export DIORITE_PATH="$DIORITE_PATH"
    export PKG_CONFIG_PATH="$DIORITE_PATH/build:$VALACEF_PATH/build:/app/lib/pkgconfig:$PKG_CONFIG_PATH"
    export VAPIDIR="$DIORITE_PATH/build:$VALACEF_PATH/build"
    export C_INCLUDE_PATH="$DIORITE_PATH/build:$VALACEF_PATH/build"
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$DIORITE_PATH/build:$VALACEF_PATH/build:/app/lib"
    export LIBRARY_PATH="$DIORITE_PATH/build:$VALACEF_PATH/build"
    export NUVOLA_ICON="eu.tiliado.NuvolaCdk"
    export DATADIR="/app/share"
    export DIORITE_TESTGEN="$DIORITE_PATH/testgen.py"
    export GI_TYPELIB_PATH="$PWD/build:$PWD/build/engineio-soup/src:$DIORITE_PATH/build:$GI_TYPELIB_PATH"
    export CEF_SUBPROCESS_PATH="$VALACEF_PATH/build/ValacefSubprocess"
    export NUVOLA_USE_CEF="true"
fi

if [ ! -f web_apps/test/unit.js ]
then
    ln -sv "$DATADIR/javascript/unitjs/unit.js" web_apps/test/unit.js
fi

bootstrap_demo_player() {
    "$(python3 -m nuvolasdk data-dir)/demo/bootstrap.sh"
}
