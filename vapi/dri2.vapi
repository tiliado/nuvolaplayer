namespace Dri2
{
	[CCode(cname="DRI2InitDisplay", cheader_filename="X11/extensions/dri2.h")]
	public bool init_display(X.Display dpy, EventOps ops);
	
	[CCode(cname="DRI2QueryExtension", cheader_filename="X11/extensions/dri2.h")]
	public bool query_extension(X.Display dpy, out int eventBase, out int errorBase);
	
	[CCode(cname="DRI2QueryVersion", cheader_filename="X11/extensions/dri2.h")]
	public bool query_version(X.Display dpy, out int major, out int minor);
	
	[CCode(cname="DRI2Connect", cheader_filename="X11/extensions/dri2.h")]
	public bool connect(X.Display dpy, X.Window root, int driverType, out string driver, out string device);
	
	[CCode(cname="DRI2DriverDRI", cheader_filename="X11/extensions/dri2.h")]
	public const int DriverDRI;
	
	[CCode(cname="DRI2EventOps", cheader_filename="X11/extensions/dri2.h")]
	public struct EventOps
	{
	}
}
