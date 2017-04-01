if [ -z "$DIORITE_PATH" ]; then DIORITE_PATH="$1"; fi

if [ -z "$DIORITE_PATH" -o ! -d "$DIORITE_PATH" ]; then
	echo "Error: Specify the path to the Diorite library repository checkout as the first argument"
else
	WAF_CONFIGURE=" --flatpak --cdk --webkitgtk-supports-mse --tiliado-oauth2-client-id="
	. setup_env.sh
	export DIORITE_PATH="$DIORITE_PATH"
	export PKG_CONFIG_PATH="$DIORITE_PATH/build:/app/lib/pkgconfig:$PKG_CONFIG_PATH"
	export VAPIDIR="$DIORITE_PATH/build"
	export C_INCLUDE_PATH="$DIORITE_PATH/build"
	export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$DIORITE_PATH/build"
	export LIBRARY_PATH="$DIORITE_PATH/build"
fi
