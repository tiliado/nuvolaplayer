/*
 * Copyright 2014-2020 Jiří Janoušek <janousek.jiri@gmail.com>
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
using GL;

namespace Nuvola {

public errordomain OffscreenWebEngineError {
    FOO,
    VERTEX_SHADER,
    FRAGMENT_SHADER,
    PROGRAM;
}


const string RECT_VERTEX_SHADER = """
#version 300 es
layout (location = 0) in vec2 in_pos_2d;
layout (location = 1) in vec2 in_texture_coordinates;
out vec2 texture_coordinates;

void main()
{
    gl_Position = vec4(in_pos_2d, 0.0, 1.0);
    texture_coordinates = in_texture_coordinates;
}
""";

const string RECT_FRAGMENT_SHADER = """
#version 300 es
precision mediump float;
in vec2 texture_coordinates;
uniform sampler2D texture_unit;
out vec4 FragColor;

void main()
{
    FragColor = texture(texture_unit, texture_coordinates);
}
""";


public class OffscreenWebView : Gtk.GLArea {
    private GLuint gl_program = 0;
    private GLuint gl_element_buffer = 0;
    private GLuint gl_vertex_buffer = 0;
    private GLuint gl_vertex_array = 0;
    private GLuint gl_texture_loading_icon = 0;
    private Gdk.Pixbuf? loading_icon = null;
    private int width = 0;
    private int height = 0;
    public Gdk.RGBA background_color {
        get; set; default = Gdk.RGBA() {red = 0.2, green = 0.2, blue = 0.2, alpha = 1.0};
    }

    public OffscreenWebView() {
        realize.connect(on_realize);
        unrealize.connect(on_unrealize);
        // set_auto_render(false);  // call queue_render() manually
    }

    public override bool render(Gdk.GLContext ctx) {
        draw_texture(0, 0, 0);
        return true; // true = stop, false = continue
    }

    public override void resize(int width, int height) {
        debug("Resize: %d×%d", width, height);
        this.width = width;
        this.height = height;
    }

    private void on_realize() {
        make_current();
        if (get_error() != null) {
            return;
        }

        try {
            init_gl();
        } catch (OffscreenWebEngineError e) {
            warning("Failure: %s", e.message);
            free_gl();
            set_error(e);
        }
    }

    private void on_unrealize() {
        make_current();
        if (get_error() != null) {
            return;
        }

        free_gl();
    }

    private void init_gl() throws OffscreenWebEngineError {
        // Many thanks to https://learnopengl.com/Getting-started/Hello-Triangle
        GLubyte info_log[1024];
        GL.GLsizei length[1];
        GLint status[1];

        // Vertex shader
        GLuint gl_vertex_shader = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(gl_vertex_shader, 1, {RECT_VERTEX_SHADER}, null);
        glCompileShader(gl_vertex_shader);
        glGetShaderiv(gl_vertex_shader, GL_COMPILE_STATUS, status);

        if (status[0] == 0) {
            glGetShaderInfoLog(gl_vertex_shader, 1024, length, info_log);
            glDeleteShader(gl_vertex_shader);
            throw new OffscreenWebEngineError.VERTEX_SHADER(
                "Failed to compile vertex shader: %s",
                (string) info_log
            );
        }

        // Fragment shader
        GLuint gl_fragment_shader = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(gl_fragment_shader, 1, {RECT_FRAGMENT_SHADER}, null);
        glCompileShader(gl_fragment_shader);
        glGetShaderiv(gl_fragment_shader, GL_COMPILE_STATUS, status);

        if (status[0] == 0) {
            glGetShaderInfoLog(gl_fragment_shader, 1024, length, info_log);
            glDeleteShader(gl_vertex_shader);
            glDeleteShader(gl_fragment_shader);
            throw new OffscreenWebEngineError.FRAGMENT_SHADER(
                "Failed to compile fragment shader: %s",
                (string) info_log
            );
        }

        gl_program = glCreateProgram();
        glAttachShader(gl_program, gl_fragment_shader);
        glAttachShader(gl_program, gl_vertex_shader);
        glLinkProgram(gl_program);
        glDeleteShader(gl_vertex_shader);
        glDeleteShader(gl_fragment_shader);


        glGetProgramiv(gl_program, GL_LINK_STATUS, status);
        if (status[0] == 0) {
            glGetProgramInfoLog(gl_program, 1024, length, info_log);
            throw new OffscreenWebEngineError.PROGRAM(
                "Failed to link program: %s",
                (string) info_log
            );
        }

        // Allocate objects
        GLuint gl_vertex_arrays[1];
        glGenVertexArrays(1, gl_vertex_arrays);
        GLuint gl_buffers[2];
        glGenBuffers(2, gl_buffers);

        // Vertex array object (VAO)
        gl_vertex_array = gl_vertex_arrays[0];
        glBindVertexArray(gl_vertex_array);

        // Vertex buffer object (VBO)
        gl_vertex_buffer = gl_buffers[0];
        glBindBuffer(GL_ARRAY_BUFFER, gl_vertex_buffer);
        float[] rect_vertices = {
            // positions[2] + texture coordinates[2]
            1.0f, 1.0f, 1.0f, 1.0f, // top right
            1.0f, -1.0f, 1.0f, 0.0f, // bottom right
            -1.0f, -1.0f, 0.0f, 0.0f, // bottom left
            -1.0f, 1.0f, 0.0f, 1.0f, // top left
        };
        glBufferData(GL_ARRAY_BUFFER, (GLsizei) (rect_vertices.length * sizeof(float)), (GLvoid[]) rect_vertices, GL_STATIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(
            0, // location for pos_2d
            2, // size - x & y coordinates
            GL_FLOAT, // type
            (GLboolean) GL_FALSE, // do not normalize
            (GLsizei) (4 * sizeof(float)), // distance between neighbors
            (void*) 0 // offset of the first item
        );

        glEnableVertexAttribArray(1);
        glVertexAttribPointer(
            1, // location for texture_coordinates
            2, // size - x & y coordinates
            GL_FLOAT, // type
            (GLboolean) GL_FALSE, // do not normalize
            (GLsizei) (4 * sizeof(float)), // distance between neighbors
            (void*) (2 * sizeof(float))  // offset of the first item
        );

        // Element buffer object (EBO)
        int[] rect_indices = {
            0, 1, 2, // first triangle
            0, 2, 3, // second triangle
        };
        gl_element_buffer = gl_buffers[1];
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl_element_buffer);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, (GLsizei) (rect_indices.length * sizeof(int)), (GLvoid[]) rect_indices, GL_STATIC_DRAW);

        Gtk.IconTheme icons = Gtk.IconTheme.get_default();
        try {
            loading_icon = icons.load_icon("image-loading", 256, 0);
            int width = loading_icon.width;
            int height = loading_icon.height;
            if (!loading_icon.get_has_alpha()) {
                loading_icon = loading_icon.add_alpha(false, 0, 0, 0);
            }
            void* data = (void*) loading_icon.read_pixels();

            GLuint gl_textures[1];
            glGenTextures(1, gl_textures);
            gl_texture_loading_icon = gl_textures[0];
            glActiveTexture(GL_TEXTURE1);
            glBindTexture(GL_TEXTURE_2D, gl_texture_loading_icon);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_REPEAT);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, data);
        } catch (GLib.Error e) {
            warning("Cannot load icon: %s", e.message);
        }

        // Finish
        glUseProgram(0);
        glBindVertexArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    }

    private void free_gl() {
        glBindVertexArray(0);
        glUseProgram(0);

        if (gl_vertex_array != 0) {
            glDeleteVertexArrays(1, {gl_vertex_array});
            gl_vertex_array = 0;
        }
        if (gl_vertex_buffer != 0) {
            glDeleteBuffers(1, {gl_vertex_buffer});
            gl_vertex_buffer = 0;
        }
        if (gl_element_buffer != 0) {
            glDeleteBuffers(1, {gl_element_buffer});
            gl_element_buffer = 0;
        }
        if (gl_program != 0) {
            glDeleteProgram(gl_program);
            gl_program = 0;
        }
    }

    private void draw_texture(GLuint texture_id, int width, int height) {
        glClearColor(
            (GLfloat) background_color.red,
            (GLfloat) background_color.green,
            (GLfloat) background_color.blue,
            (GLfloat) background_color.alpha
        );
        glClear(GL_COLOR_BUFFER_BIT);

        if (texture_id == 0) {
            texture_id = gl_texture_loading_icon;
            width = loading_icon.width;
            height = loading_icon.height;
        } else {
            if (width <= 0) {
                width = this.width;
            }
            if (height <= 0) {
                height = this.height;
            }
        }

        // Center viewport
        glViewport((this.width - width) / 2, (this.height - height) / 2, width, height);

        if (texture_id != 0) {
            debug("Rendering texture %u with %u.", texture_id, gl_program);
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            glUseProgram(gl_program);
            glActiveTexture(GL_TEXTURE1);
            glBindTexture(GL_TEXTURE_2D, texture_id);
            GLint texture_location = glGetUniformLocation(gl_program, "texture_unit");
            glUniform1i(texture_location, 1);
            glBindVertexArray(gl_vertex_array);
            glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, (void*) 0);
            glUseProgram(0);
            glBindVertexArray(0);
        }
    }
}

} // namespace Nuvola
