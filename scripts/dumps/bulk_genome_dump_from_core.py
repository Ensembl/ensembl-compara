#!/usr/bin/env python3
"""
Wrapper of dump_genome_from_core.pl to dump a list of FASTA files
"""
import argparse
import subprocess
import os
import sys

try:
    import yaml
    from yaml.loader import SafeLoader  # For older PyYAML versions
except ModuleNotFoundError:
    print(
        "Error: The 'PyYAML' module is not installed. Please install it using 'pip install PyYAML'."
    )
    sys.exit(1)  # Exit with an error code


def detect_job_scheduler():
    """
    Detect if the system is using SLURM, LSF, or no job scheduler.

    Returns:
        str: The name of the detected job scheduler ('SLURM', 'LSF') or 'NONE' if no known scheduler is found.
    """

    schedulers = {
        "SLURM": "srun",
        "LSF": "bsub",
    }

    for scheduler, command in schedulers.items():
        if (
            subprocess.run(
                ["which", command],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            ).returncode
            == 0
        ):
            return scheduler

    return "NONE"  # Return 'NONE' if no scheduler is found


def subprocess_call(command, work_dir=None, shell=False):
    """
    Subprocess function to execute the given command line.

    Args:
        command (list): The command that the subprocess will execute.
        work_dir (str): The location where the command should be run.
        shell (bool): If True, the specified command will be executed through the shell.

    Returns:
        str: The subprocess output or None otherwise.
    """
    job_scheduler = detect_job_scheduler()

    if job_scheduler == "NONE":
        print("Error: No job scheduler detected.")
        sys.exit(1)

    if job_scheduler == "SLURM":
        command = [
            "sbatch",
            "--time=1-00",
            "--mem-per-cpu=4gb",
            "--cpus-per-task=1",
            "--export=ALL",
            f"--wrap={' '.join(command)}",
        ]
    elif job_scheduler == "LSF":
        command = ["bsub", "-W", "1:00", "-R", "rusage[mem=4096]"] + command

    print(f"Running: {' '.join(command)}")
    with subprocess.Popen(
        command,
        shell=shell,
        cwd=work_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    ) as process:
        output, stderr = process.communicate()

        if process.returncode != 0:
            out = f"stdout={output}, stderr={stderr}"
            raise RuntimeError(
                f"Command {' '.join(command)} exited {process.returncode}: {out}"
            )

        print(f"Successfully ran: {' '.join(command)}")
        return output.strip()


def download_file(host, port, core_db, fasta_filename, mask="soft"):
    """
    Download the FASTA file from the core DB using a PERL script `dump_genome_from_core.pl`.

    Args:
        host (str): The DB host name.
        port (str): The port number.
        core_db (str): The core_db name.
        fasta_filename (str): The name given for the FASTA file.
        mask (str): The mask format for the FASTA file.

    Returns:
        str: The output of the subprocess call to download the FASTA file.
    """
    work_dir = f"{os.environ['ENSEMBL_ROOT_DIR']}/main/ensembl-compara/scripts/dumps"
    script = "dump_genome_from_core.pl"

    perl_call = [
        "perl",
        f"{work_dir}/{script}",
        "--core_db",
        core_db,
        "--host",
        host,
        "--port",
        port,
        "--mask",
        mask,
        "--outfile",
        fasta_filename,
    ]
    return subprocess_call(command=perl_call)


def query_coredb(host, core_db, query):
    """
    Get the correct meta production name.

    Args:
        host (str): The DB host name.
        core_db (str): The core_db name.
        query (str): The query to be executed.

    Returns:
        str: The output of the subprocess call to query the database.
    """
    mysql_call = ["mysql", "-h", host, core_db, "-ss", "-e", query]
    return subprocess_call(command=mysql_call)


def parse_yaml(file, dest):
    """
    YAML parser.

    Args:
        file (file object): The file object.
        dest (str): The destination PATH where the FASTA file will be stored.
    """
    content = yaml.load(file, Loader=SafeLoader)
    for data in content:
        host = data["host"]
        port = data["port"]

        for core_db in data["core_db"]:
            fasta_file_name = query_coredb(
                host=host,
                core_db=core_db,
                query="SELECT meta_value FROM meta WHERE meta_key='species.production_name';",
            )

            if "_gca" not in fasta_file_name:
                gca_number = query_coredb(
                    host=host,
                    core_db=core_db,
                    query="SELECT meta_value FROM meta WHERE meta_key='assembly.accession';",
                )
                gca_number = gca_number.replace(".", "v").replace("_", "").lower()
                fasta_file_name = f"{fasta_file_name}_{gca_number}"

            if fasta_file_name:
                download_file(
                    host=host,
                    port=port,
                    core_db=core_db,
                    fasta_filename=f"{dest}/{fasta_file_name}.fa",
                )
            else:
                raise ValueError(f"Problem with {fasta_file_name}")


def main():
    """
    Main function to parse arguments and handle the processing of a YAML file to dump a list of FASTA files.
    """
    parser = argparse.ArgumentParser(
        description="Wrapper of dump_genome_from_core.pl to dump a list of FASTA files."
    )
    parser.add_argument("--yaml", required=True, type=str, help="YAML input file")
    parser.add_argument(
        "--output",
        required=False,
        default=None,
        type=str,
        help="Processed output directory",
    )
    args = parser.parse_args()

    with open(args.yaml, mode="r", encoding="utf-8") as f:
        if args.output is None:
            args.output = os.path.dirname(os.path.realpath(f.name))
        else:
            args.output = os.path.abspath(args.output)

        if not os.path.isdir(args.output):
            print(f"{args.output} does not exist for output, please create it first")
            sys.exit(1)

        parse_yaml(file=f, dest=args.output)


if __name__ == "__main__":
    main()
