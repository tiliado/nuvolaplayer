/* 
 * Author: Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * To the extent possible under law, author has waived all
 * copyright and related or neighboring rights to this file.
 * http://creativecommons.org/publicdomain/zero/1.0/
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * Tests are under public domain because they might contain useful sample code.
 */

namespace Nuvola
{

public class GraphicsTest: Drt.TestCase
{
	public void test_dri2_get_driver_name()
	{
		try
		{
			var name = Graphics.dri2_get_driver_name();
			expect_false(Drt.String.is_empty(name), "driver name not empty");
		}
		catch (Graphics.DriError e)
		{
			if (!(e is Graphics.DriError.NO_X_DISPLAY))
				expectation_failed("Unexpected error: %s %d %s", e.domain.to_string(), e.code, e.message);
		}
	}
	
	public void test_have_vdpau_driver()
	{
		var name = "i965";
		var result = Graphics.have_vdpau_driver(name);
		var expected = FileUtils.test("/usr/lib/vdpau/libvdpau_i965.so", FileTest.EXISTS)
		|| FileUtils.test("/app/lib/vdpau/libvdpau_i965.so", FileTest.EXISTS);
		expect_true(expected == result, "have vdpau driver");
	}
	
	public void test_have_vaapi_driver()
	{
		var name = "i965";
		var result = Graphics.have_vaapi_driver(name);
		var expected = FileUtils.test("/usr/lib/drv/i965_drv_video.so", FileTest.EXISTS)
		|| FileUtils.test("/app/lib/dri/i965_drv_video.so", FileTest.EXISTS);
		expect_true(expected == result, "have vaapi driver");
	}
}

} // namespace Nuvola
