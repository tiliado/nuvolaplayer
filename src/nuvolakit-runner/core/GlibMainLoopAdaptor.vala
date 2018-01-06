namespace Nuvola {

public class GlibMainLoopAdaptor : MainLoopAdaptor {
	private MainLoop? loop = null;
	
	public GlibMainLoopAdaptor() {
		base();
	}
	
	public override void run() {
		if (loop == null) {
			loop = new MainLoop();
			loop.run();
		}
	}
	
	public override void quit() {
		if (loop != null) {
			loop.quit();
			loop = null;
		}
	}
}

} // namespace Nuvola
