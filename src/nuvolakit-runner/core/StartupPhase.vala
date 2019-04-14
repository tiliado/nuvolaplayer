/*
 * Copyright 2018-2019 Jiří Janoušek <janousek.jiri@gmail.com>
 * Licensed under BSD-2-Clause license, see the file LICENSE for details.
 */

namespace Nuvola {

public enum StartupPhase {
    NONE,
    IN_PROGRESS,
    WARNING,
    ERROR,
    CHECKS_DONE,
    WELCOME,
    TERMS,
    ALL_DONE;
}

} // namespace Nuvola
