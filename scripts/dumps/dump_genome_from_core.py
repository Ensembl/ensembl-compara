#!/usr/bin/env python3

import fileinput
import argparse
import subprocess
import os
import yaml
from yaml.loader import SafeLoader


def subprocess_call(command, work_dir=None, shell=False, ibsub=False):
    """Subprocess function to spin  the given command line`

    Args:
        command: the command that the subprocess will spin
        work_dir: the location where the command should be run
        shell: if shell is True, the specified command will be executed through the shell.
        ibsub: if ibsub is True, the command will be called via ibsub

    Returns:
        The subprocess output

    """

    if ibsub:
        command = ["ibsub", "-d"] + command

    call = command
    print("Running: {}".format(" ".join(call)))
    process = subprocess.Popen(
        call,
        shell=shell,
        encoding="ascii",
        cwd=work_dir,
        stdout=subprocess.PIPE,
        universal_newlines=True,
    )

    output, stderr = process.communicate()

    process.wait()
    if process.returncode != 0:
        out = "stdout={}".format(output)
        out += ", stderr={}".format(stderr)
        raise RuntimeError(
            "Command {} exited {}: {}".format(call, process.returncode, out)
        )
    else:
        print("Successfully ran: {}".format(" ".join(call)))

    return output.strip()


def download_file(host, port, core_db, fasta_filename, mask="soft"):
    """Download the FASTA file from the core db using a PERL script `dump_genome_from_core.pl`

    Args:
        host: The DB host name
        port: The port number
        core_db: The core_db name
        fasta_filename: The name given for the FASTA file
        mask: The mask format for the FASTA file.

    Returns:
        A subprocess call object to download the FASTA file using the PERL script.

    """

    work_dir = "{}/../master/ensembl-compara/scripts/dumps".format(
        os.environ["ENSEMBL_ROOT_DIR"]
    )
    script = "dump_genome_from_core.pl"

    perl_call = [
        "perl",
        "{}/{}".format(work_dir, script),
        "--core_db",
        "{}".format(core_db),
        "--host",
        "{}".format(host),
        "--port",
        "{}".format(port),
        "--mask",
        "{}".format(mask),
        "--outfile",
        "{}".format(fasta_filename),
    ]
    return subprocess_call(command=perl_call, ibsub=True, shell=False)


def get_name(host, core_db):
    """Get the correct meta production name

    Args:
        host: The DB host name
        core_db: The core_db name

    Returns:
        A subprocess call object to query the database.

    """
    mysql_call = [
        "{}".format(host),
        "{}".format(core_db),
        "-ss",
        "-e",
        'SELECT meta_value FROM meta WHERE meta_key="species.production_name";',
    ]
    return subprocess_call(command=mysql_call)


def parse_yaml(file, dest):
    """YAML parser.

    Args:
        file: The file object

        dest: The destination PATH where the FASTA file will be stored
    """
    content = yaml.load(file, Loader=SafeLoader)
    for data in content:

        host = data["host"]
        port = data["port"]

        for core_db in data["core_db"]:
            name = get_name(host=host, core_db=core_db)
            name = name.replace("_", ".")
            download_file(
                host=host,
                port=port,
                core_db=core_db,
                fasta_filename="{}/{}.fa".format(dest, name),
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--yaml", required=True, type=str, help="YAML input file")
    parser.add_argument(
        "--output", required=False, default=None, type=str, help="Processed output file"
    )
    args = parser.parse_args()

    with open(args.yaml, mode="r") as f:

        if args.output is None:
            args.output = os.path.dirname(os.path.realpath(f.name))
        else:
            args.output = os.path.abspath(args.output)

        parse_yaml(file=f, dest=args.output)
