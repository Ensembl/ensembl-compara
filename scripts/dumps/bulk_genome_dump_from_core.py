#!/usr/bin/env python
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""
Wrapper of dump_genome_from_core.pl to dump a list of FASTA files
"""
import argparse
import subprocess
import os
import sys
import logging

try:
    import yaml
    from yaml.loader import SafeLoader  # For older PyYAML versions
except ModuleNotFoundError:
    logging.critical(
        "Error: The 'PyYAML' module is not installed. Please install it using 'pip install PyYAML'."
    )
    sys.exit(1)  # Exit with an error code


def setup_logging():
    """
    Sets up logging configuration.
    """
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
    )


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


def subprocess_call(
    command, work_dir=None, shell=False, use_job_scheduler=False, job_name=None
):
    """
    Subprocess function to execute the given command line.

    Args:
        command (list): The command that the subprocess will execute.
        work_dir (str): The location where the command should be run.
        shell (bool): If True, the specified command will be executed through the shell.
        use_job_scheduler (bool): If True, the command will be submitted to a job scheduler.

    Returns:
        str: The subprocess output or None otherwise.
    """
    if use_job_scheduler:
        job_scheduler = detect_job_scheduler()

        if job_scheduler == "NONE":
            logging.error("No job scheduler detected.")
            sys.exit(1)

        if job_scheduler == "SLURM":
            command = [
                "sbatch",
                "--time=1-00",
                "--mem-per-cpu=4gb",
                "--cpus-per-task=1",
                "--export=ALL",
                f"--job-name={job_name}",
                f"--wrap={' '.join(command)}",
            ]
        elif job_scheduler == "LSF":
            command = [
                "bsub",
                "-W",
                "1:00",
                "-R",
                "rusage[mem=4096]",
                "-J",
                job_name,
            ] + command

    logging.info("Running: %s", " ".join(command))
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
            logging.error(
                "Command %s exited %d: %s", " ".join(command), process.returncode, out
            )
            raise RuntimeError(
                f"Command {' '.join(command)} exited {process.returncode}: {out}"
            )

        logging.info("Successfully ran: %s", " ".join(command))
        return output.strip()


def download_file(
    host, port, core_db, fasta_filename, genome_component="", mask="soft"
):
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
    try:
        work_dir = os.path.join(
            os.environ["ENSEMBL_ROOT_DIR"],
            "ensembl-compara",
            "scripts",
            "dumps",
        )
        script = "dump_genome_from_core.pl"

        perl_call = [
            "perl",
            os.path.join(work_dir, script),
            "--core_db",
            core_db,
            "--host",
            host,
            "--port",
            str(port),
            "--mask",
            mask,
            "-user",
            "ensro",
            "--outfile",
            fasta_filename,
        ]

        # Conditionally add the genome component argument
        if genome_component:
            perl_call += ["--genome-component", genome_component]

        logging.info("perl_call=%s", perl_call)
        return subprocess_call(
            command=perl_call,
            use_job_scheduler=True,
            job_name=f"{core_db}_{genome_component}",
        )

    except KeyError as e:
        logging.error("Environment variable not set: %s", e)
        raise

    except Exception as e:
        logging.error("An unexpected error occurred: %s", e)
        raise


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
    mysql_call = [host, core_db, "-N", "-e", query]
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
        include_gca_number = data["gca_number"]

        for core_db in data["core_db"]:
            fasta_file_name = query_coredb(
                host=host,
                core_db=core_db,
                query="SELECT meta_value FROM meta WHERE meta_key='species.production_name';",
            )

            if include_gca_number:
                gca_number = query_coredb(
                    host=host,
                    core_db=core_db,
                    query="SELECT meta_value FROM meta WHERE meta_key='assembly.accession';",
                )
                gca_number = gca_number.replace(".", "v").replace("_", "").lower()
                fasta_file_name = f"{fasta_file_name}_{gca_number}"

            # Query the genome components and split the result
            genome_components = [
                component
                for component in query_coredb(
                    host=host,
                    core_db=core_db,
                    query=(
                        "SELECT DISTINCT value FROM seq_region_attrib "
                        "JOIN attrib_type USING (attrib_type_id) "
                        "WHERE attrib_type.code='genome_component';"
                    ),
                ).split("\n")
                if component
            ]

            # Generate dump filenames
            dump_filenames = (
                [
                    (f"{fasta_file_name}_{component}", component)
                    for component in genome_components
                ]
                if genome_components
                else [(fasta_file_name, "")]
            )

            # Process each filename
            for filename, genome_component in dump_filenames:
                logging.info("fasta_file_name=%s", filename)
                logging.info("genome_component=%s", genome_component)

                download_file(
                    host=host,
                    port=port,
                    core_db=core_db,
                    genome_component=genome_component,
                    fasta_filename=os.path.join(dest, f"{filename}.fa"),
                )


def main():
    """
    Main function to parse arguments and handle the processing of a YAML file to dump a list of FASTA files.
    """
    setup_logging()

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
            logging.error(
                "%s does not exist for output, please create it first", args.output
            )
            sys.exit(1)

        parse_yaml(file=f, dest=args.output)


if __name__ == "__main__":
    main()
