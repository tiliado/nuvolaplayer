#if HAVE_CEF
namespace Nuvola {

public class CefMainLoopAdaptor : MainLoopAdaptor {
	private bool running = false;
	
	public CefMainLoopAdaptor() {
		base();
	}
	
	public override void run() {
		if (!running) {
			running = true;
			CefGtk.run_main_loop();
		}
	}
	
	public override void quit() {
		if (running) {
			running = false;
			CefGtk.quit_main_loop();
		}
	}
}

} // namespace Nuvola
#endif
