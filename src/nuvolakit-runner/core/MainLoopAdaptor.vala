namespace Nuvola {

public abstract class MainLoopAdaptor {
	private MainLoopAdaptor? replacement = null;
	
	public MainLoopAdaptor() {
	}
	
	public abstract void run();
	public abstract void quit();
	
	public MainLoopAdaptor? get_replacement() {
		return replacement;
	}
	
	public void replace(MainLoopAdaptor replacement) {
		this.replacement = replacement;
		quit();
	}
}

} // namespace Nuvola
