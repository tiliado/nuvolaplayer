/*
 * Copyright 2018-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class Nuvola.ArchiveReader {
    private Archive.Read? reader = null;
    private unowned Archive.Entry? entry = null;

    public ArchiveReader(string path, int block_size) throws ArchiveReaderError {
        reader = new Archive.Read();
        reader.support_format_all();
        reader.support_filter_all();
        if (not_ok(reader.open_filename(path, block_size))) {
            throw new ArchiveReaderError.OPEN("Cannot open archive '%s'. %s", path, reader.error_string());
        }
    }

    private ArchiveReader.inner(
        Archive.OpenCallback open_cb, Archive.ReadCallback read_cb, Archive.CloseCallback close_cb
    ) throws ArchiveReaderError {
        reader = new Archive.Read();
        reader.support_format_all();
        reader.support_filter_all();
        if (not_ok(reader.open(open_cb, read_cb, close_cb))) {
            throw new ArchiveReaderError.OPEN("Cannot open inner archive. %s", reader.error_string());
        }
    }

    public bool next(out unowned Archive.Entry? entry) {
        if (is_ok(reader.next_header(out this.entry))) {
            entry = this.entry;
            return true;
        }
        entry = null;
        return false;
    }

    public ArchiveReader read_archive() throws ArchiveReaderError {
        return new ArchiveReader.inner(noop_cb, read_callback, noop_cb);
    }

    public void read_data_to_file(string path) throws GLib.Error {
        string tmp_path = path + ".tmpXXXXXX";
        int fd = FileUtils.mkstemp(tmp_path);
        if (fd < 0) {
            throw new ArchiveReaderError.OPEN("Cannot open temporary file '%s'.", tmp_path);
        }
        try {
            if (not_ok(reader.read_data_into_fd(fd))) {
                throw new ArchiveReaderError.READ("Failed to read archive data. %", reader.error_string());
            }
            if (FileUtils.rename(tmp_path, path) != 0) {
                throw new ArchiveReaderError.RENAME("Cannot rename '%s' to '%s'.", tmp_path, path);
            }
        } finally {
            FileUtils.close(fd);
            FileUtils.unlink(tmp_path);
        }
    }

    private ssize_t read_callback(Archive.Archive archive, out void* buffer) {
        const int BUFFER_SIZE = 4096;
        buffer = GLib.malloc(BUFFER_SIZE);
        return reader.read_data(buffer, BUFFER_SIZE);
    }

    private int noop_cb(Archive.Archive archive) {
        return Archive.Result.OK;
    }

    private static bool is_ok(Archive.Result result) {
        return result == Archive.Result.OK;
    }

    private static bool not_ok(Archive.Result result) {
        return result != Archive.Result.OK;
    }
}

public errordomain Nuvola.ArchiveReaderError {
    OPEN,
    RENAME,
    READ;
}
