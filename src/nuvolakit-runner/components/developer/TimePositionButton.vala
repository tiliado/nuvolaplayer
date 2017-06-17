/*
 * Copyright 2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola
{

/**
 * Button which shows position inside a time interval and a popover with a slider
 * is shown when the button is clicked.
 */
public class TimePositionButton: Drt.PopoverButton
{
	public int start_sec {get ; set; default = 0;}
	public int position_sec {get; set; default = 0;}
	public int end_sec {get; set; default = 1;}
	public Gtk.Orientation orientation {get; set; default = Gtk.Orientation.HORIZONTAL;}
	private Gtk.Scale scale;
	
	/**
	 * Create new TimePositionButton
	 * 
	 * @param start_sec         The start time in seconds.
	 * @param end_sec           The end time in seconds.
	 * @param position_sec      The current time in seconds.
	 * @param orientation       The orientation of the slider.
	 */
	public TimePositionButton(int start_sec, int end_sec, int position_sec,
		Gtk.Orientation orientation=Gtk.Orientation.HORIZONTAL)
	{
		GLib.Object(start_sec: start_sec, end_sec: end_sec, position_sec: position_sec, orientation: orientation);
	}
	
	construct {
		update_label();
		scale = new Gtk.Scale.with_range(orientation, start_sec * 1.0, end_sec * 1.0, 1.0);
		popover.add(scale);
		scale.set_size_request(200, -1);
		scale.format_value.connect(format_time_double);
		scale.margin = 20;
		scale.show();
		this.bind_property("orientation", scale, "orientation", GLib.BindingFlags.DEFAULT);
		this.bind_property("start-sec", scale.adjustment, "lower", GLib.BindingFlags.BIDIRECTIONAL);
		this.bind_property("end-sec", scale.adjustment, "upper", GLib.BindingFlags.BIDIRECTIONAL);
		this.bind_property("position-sec", scale.adjustment, "value", GLib.BindingFlags.DEFAULT);
		notify["position-sec"].connect_after(update_label);
		notify["end-sec"].connect_after(update_label);
		scale.value_changed.connect_after(on_value_changed);
	}
	
	~TimePositionButton()
	{
		scale.format_value.disconnect(format_time_double);
		notify["position-sec"].disconnect(update_label);
		notify["end-sec"].disconnect(update_label);
		scale.value_changed.disconnect(on_value_changed);
	}
	
	/**
	 * Emitted when position is changed as a result of user action.
	 */
	public signal void position_changed();
	
	private void update_label()
	{
		label = "%s/%s".printf(format_time(position_sec), format_time(end_sec));
	}
	
	private string format_time(int seconds)
	{
		var hours = seconds / 3600;
		var result = (hours > 0) ? "%02d:".printf(hours) : "";
		seconds = (seconds - hours * 3600);
		var minutes = seconds / 60;
		seconds = (seconds - minutes * 60);
		return result + "%02d:%02d".printf(minutes, seconds);
	}
	
	private string format_time_double(double seconds)
	{
		return format_time(round_sec(seconds));
	}
	
	private inline int round_sec(double sec)
	{
		return (int) Math.round(sec);
	}
	
	private void on_value_changed(Gtk.Range scale)
	{
		var position = round_sec(scale.adjustment.value);
		if (position_sec != position)
		{
			position_sec = position;
			position_changed();
		}
	}
}

} // namespace Nuvola
