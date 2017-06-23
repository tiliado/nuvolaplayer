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

public class GraphicsTest: Diorite.TestCase
{
	public void test_dri2_get_driver_name()
	{
		string? name = null;
		expect_no_error(() => name = Graphics.dri2_get_driver_name(), "driver name");
		expect_false(Diorite.String.is_empty(name), "driver name not empty");
	}
	
	public void test_have_vdpau_driver()
	{
		var name = "i965";
		var result = Graphics.have_vdpau_driver(name);
		var expected = FileUtils.test("/usr/lib/libvdpau_i965.so", FileTest.EXISTS)
		|| FileUtils.test("/app/lib/libvdpau_i965.so", FileTest.EXISTS);
		expect_true(expected == result, "have vdpau driver");
	}
}

} // namespace Nuvola
