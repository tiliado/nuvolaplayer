/*
 * Copyright 2017-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola {

/**
 * VersionTuple holds version information
 */
public struct VersionTuple {
    public uint major;
    public uint minor;
    public uint micro;
    public uint patch;

    /**
     * Create new version tuple.
     *
     * @param major    The major version number.
     * @param minor    The minor version number.
     * @param micro    The micro version number.
     * @param patch    The micro version patch.
     */
    public VersionTuple(uint major=0, uint minor=0, uint micro=0, uint patch=0) {
        this.major = major;
        this.minor = minor;
        this.micro = micro;
        this.patch = patch;
    }

    /**
     * Create new version tuple from uint array.
     *
     * @param versions    Version numbers as an uint array.
     */
    public VersionTuple.uintv(uint[] versions) {
        this.major = versions.length > 0 ? versions[0] : 0;
        this.minor = versions.length > 1 ? versions[1] : 0;
        this.micro = versions.length > 2 ? versions[2] : 0;
        this.patch = versions.length > 3 ? versions[3] : 0;
    }

    /**
     * Create new version tuple from version string.
     *
     * @param version    A dot-separated version string.
     */
    public VersionTuple.parse(string version) {
        string[] parts = version.split(".");
        if (parts.length > 0) {
            major = (uint) int.parse(parts[0].strip());
            if (parts.length > 1) {
                minor = (uint) int.parse(parts[1].strip());
                if (parts.length > 2) {
                    micro = (uint) int.parse(parts[2].strip());
                    if (parts.length > 3) {
                        patch = (uint) int.parse(parts[3].strip());
                    }
                }
            }
        }
    }

    /**
     * Whether this version tuple is empty.
     *
     * @return True is this version tuple is empty.
     */
    public bool empty() {
        return major == 0 && minor == 0 && micro == 0 && patch == 0;
    }

    /**
     * Check whether this version is equal to the other.
     *
     * @param other    The other version.
     * @return The result of this == other.
     */
    public bool is_equal_to(VersionTuple other) {
        return compare(other) == 0;
    }

    /**
     * Check whether this version is greater than the other.
     *
     * @param other    The other version.
     * @return The result of this > other.
     */
    public bool is_greater_than(VersionTuple other) {
        return compare(other) > 0;
    }

    /**
     * Check whether this version is greater than or equal to the other.
     *
     * @param other    The other version.
     * @return The result of this >= other.
     */
    public bool is_greater_or_equal_to(VersionTuple other) {
        return compare(other) >= 0;
    }

    /**
     * Check whether this version is lesser than the other.
     *
     * @param other    The other version.
     * @return The result of this < other.
     */
    public bool is_lesser_than(VersionTuple other) {
        return compare(other) < 0;
    }

    /**
     * Check whether this version is lesser than or equal to the other.
     *
     * @param other    The other version.
     * @return The result of this <= other.
     */
    public bool is_lesser_or_equal_to(VersionTuple other) {
        return compare(other) <= 0;
    }

    /**
     * Compare this version with the other.
     *
     * @param other    The other version.
     * @return Zero if this == other, a positive number if this > other, and a negative number if this < other.
     */
    public int compare(VersionTuple other) {
        if (other.major > major) {
            return -1;
        }
        if (other.major < major) {
            return 1;
        }
        if (other.minor > minor) {
            return -1;
        }
        if (other.minor < minor) {
            return 1;
        }
        if (other.micro > micro) {
            return -1;
        }
        if (other.micro < micro) {
            return 1;
        }
        if (other.patch > patch) {
            return -1;
        }
        if (other.patch < patch) {
            return 1;
        }
        return 0;
    }

    /**
     * Create version string.
     *
     * @return A dot-separated version string X.Y.Z or X.Y.Z.P.
     */
    public string to_string() {
        if (patch > 0 ) {
            return "%u.%u.%u.%u".printf(major, minor, micro, patch);
        } else {
            return "%u.%u.%u".printf(major, minor, micro);
        }
    }

    /**
     * Return version array.
     *
     * @return Version array.
     */
    public uint[] as_array() {
        return {major, minor, micro, patch};
    }
}

} // namespace Nuvola
