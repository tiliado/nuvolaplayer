from queue import Queue
from threading import Thread
from typing import List
from subprocess import Popen, PIPE, STDOUT


class ElectronThread(Thread):
    process: Popen
    stdout: Queue

    def __init__(self, argv: List[str]):
        super().__init__(name="ElectronThread")
        self.argv = ["/app/lib/electron/electron"] + argv
        self.process = None
        self.stdout = Queue()

    def run(self) -> int:
        stdout = self.stdout
        self.process = process = Popen(self.argv, stdout=PIPE, stderr=STDOUT, stdin=PIPE)
        for line in process.stdout:
            if line == b"":
                break
            else:
                stdout.put(line)
        process.communicate(None)
        return process.returncode
