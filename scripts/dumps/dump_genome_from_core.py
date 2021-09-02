#!/usr/bin/env python3
""" Wrapper of dump_genome_from_core.pl to dump a list of FASTA file
"""
import argparse
import subprocess
import os
import sys

try:
    import yaml
    from yaml.loader import SafeLoader
except ModuleNotFoundError as err:
    # Error handling
    print(err)
    print('Please, run "pip install PyYAML" to install PyYAML module')


def subprocess_call(command, work_dir=None, shell=False, ibsub=False):
    """Subprocess function to spin  the given command line`

    Args:
        command: the command that the subprocess will spin
        work_dir: the location where the command should be run
        shell: if shell is True, the specified command will be executed through the shell.
        ibsub: if ibsub is True, the command will be called via ibsub

    Returns:
        The subprocess output or None otherwise

    """

    if ibsub:
        command = ["ibsub", "-d"] + command

    call = command
    print("Running: {}".format(" ".join(call)))
    with subprocess.Popen(
        call,
        shell=shell,
        encoding="ascii",
        cwd=work_dir,
        stdout=subprocess.PIPE,
        universal_newlines=True,
    ) as process:

        output, stderr = process.communicate()

        process.wait()
        if process.returncode != 0:
            out = "stdout={}".format(output)
            out += ", stderr={}".format(stderr)
            raise RuntimeError(
                "Command {} exited {}: {}".format(call, process.returncode, out)
            )
        print("Successfully ran: {}".format(" ".join(call)))

        return output.strip()

    return None


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


def query_coredb(host, core_db, query):
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
        "{}".format(query),
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
            specie_name = query_coredb(
                host=host,
                core_db=core_db,
                query='SELECT meta_value FROM meta WHERE meta_key="species.production_name";',
            )

            # in case gca is presented in the specie name
            if "gca" not in specie_name:
                gca_number = query_coredb(
                    host=host,
                    core_db=core_db,
                    query='SELECT meta_value FROM meta WHERE meta_key="assembly.accession";',
                )
                gca_number = gca_number.replace(".", "v").lower()
                specie_name = "{}_{}".format(specie_name, gca_number)

            if specie_name is not None:
                download_file(
                    host=host,
                    port=port,
                    core_db=core_db,
                    fasta_filename="{}/{}.fa".format(dest, specie_name),
                )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--yaml", required=True, type=str, help="YAML input file")
    parser.add_argument(
        "--output", required=False, default=None, type=str, help="Processed output file"
    )
    args = parser.parse_args()

    with open(args.yaml, mode="r", encoding="utf-8") as f:

        if args.output is None:
            args.output = os.path.dirname(os.path.realpath(f.name))
        else:
            args.output = os.path.abspath(args.output)

        if not os.path.isdir(args.output):
            print(
                "{} does not exist for output, please create it first".format(
                    args.output
                )
            )
            sys.exit(1)

        parse_yaml(file=f, dest=args.output)
