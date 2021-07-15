import logging
import subprocess


def run_cmd(cmd: list) -> int:
    cp = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if cp.returncode != 0:
        logging.error(
            f"Command {cmd} failed exit code: {cp.returncode}\n"
            f"Command {cmd} args: {cp.args}\n"
            f"Command {cmd} stdout: {cp.stdout}\n"
            f"Command {cmd} stderr: {cp.stderr}\n"
        )
        return 1
    else:
        logging.info(
            f"Successfully run the command {cmd}\n"
            f"Command {cmd} stdout: {cp.stdout}\n"
        )

    return 0
