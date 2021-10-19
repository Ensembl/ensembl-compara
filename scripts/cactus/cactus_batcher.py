#!/usr/bin/env python3

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


"""This script prompts a user to parse the output of cactus-prepare in order to
a bash script that wraps the cactus pipeline into Slurm jobs."""

import argparse
import os
import tempfile
import stat
import sys
import shutil
import pathlib
import re
from pathlib import Path
from typing import Any, Union

try:
    import yaml
    from yaml.loader import SafeLoader
except ModuleNotFoundError as module_err:
    # Error handling
    print(module_err)
    print('Please, run "pip install PyYAML" to install PyYAML module')
    sys.exit(1)

# sanity check for environment variables CACTUS_IMAGE and CACTUS_GPU_IMAGE
for i in ["CACTUS_IMAGE", "CACTUS_GPU_IMAGE"]:
    if os.environ.get(i) is None:
        raise Exception(
            f"Please set the environment variable {i} to point to singularity image."
        )


###################################################################
###                    UTILITY   FUNCTIONS                       ##
###################################################################


def symlink(target, link_name, overwrite=False):
    """Create a symbolic link named link_name pointing to target. If link_name
    exists then FileExistsError is raised, unless overwrite=True. When trying
    to overwrite a directory, IsADirectoryError is raised.

    Credit: https://stackoverflow.com/a/55742015/825924
    """

    if not overwrite:
        os.symlink(target, link_name)
        return

    # os.replace() may fail if files are on different filesystems
    link_dir = os.path.dirname(link_name)

    # Create link to target with temporary filename
    while True:
        temp_link_name = tempfile.mktemp(dir=link_dir)

        # os.* functions mimic as closely as possible system functions
        # The POSIX symlink() returns EEXIST if link_name already exists
        # https://pubs.opengroup.org/onlinepubs/9699919799/functions/symlink.html
        try:
            os.symlink(target, temp_link_name)
            break
        except FileExistsError:
            pass

    # Replace link_name with temp_link_name
    try:
        # Pre-empt os.replace on a directory with a nicer message
        if not os.path.islink(link_name) and os.path.isdir(link_name):
            raise IsADirectoryError(
                f"Cannot symlink over existing directory: '{link_name}'"
            )
        os.replace(temp_link_name, link_name)
    except BaseException:
        if os.path.islink(temp_link_name):
            os.remove(temp_link_name)
        raise


def read_file(filename, line_number=False):
    """Function to read a file.

    Args:
        @filename: The name of the file to read
        @line_number: return the number along with the line
    """
    with open(filename, encoding="utf-8") as file:
        number = 0
        while True:
            line = file.readline()
            if not line:
                break
            if line_number:
                yield line, number
                number = number + 1
            else:
                yield line


def create_symlinks(src_dirs, dest):
    """Create relative symbolic links.

    Args:
        @src_dirs: list of source directory for symlink generation
        @dest: where the symlink must be created
    """
    pathlib.Path(dest).mkdir(parents=True, exist_ok=True)

    for src in src_dirs:
        relativepath = os.path.relpath(src, dest)
        fromfolderWithFoldername = dest + "/" + os.path.basename(src)
        symlink(target=relativepath, link_name=fromfolderWithFoldername, overwrite=True)


def append(filename, line, mode="a"):
    """Append content to a file.

    Args:
        @filename: the name of the file to append information
        @line: string to append in the file as a line
        @mode: mode to open the file
    """

    if line:
        with open(filename, mode, encoding="utf-8") as file:
            if file.tell() > 0:
                file.write("\n")
            file.write(line.strip())


def mkdir(path, force=False):
    """Create a directory.

    Args:
        @path: path to create directories
        @force: if the directory exists, delete and recreate it
    """
    if force and Path(path).exists():
        shutil.rmtree(path)

    Path(path).mkdir(parents=True, exist_ok=True)


def make_executable(path):
    """Make a file executable, e.g., chmod +x.

    Args:
        @path: path to a file
    """
    st = os.stat(path)
    os.chmod(path, st.st_mode | stat.S_IEXEC)


def create_bash_script(filename, chmod_x=True, shebang="#!/bin/bash"):
    """Create executable bash script with shebang on it.

    Args:

        @filename: Path of the file
        @shebang: String containing bash shebang
    """
    append(filename=filename, mode="w", line=shebang)

    # chmod +x on it
    if chmod_x:
        make_executable(path=filename)


def create_argparser():
    """Create argparser object to parse the input for this script."""

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--commands",
        metavar="PATH",
        type=str,
        required=True,
        help="File containing the command lines generated by the cactus-prepare",
    )
    parser.add_argument(
        "--steps_dir",
        metavar="PATH",
        type=str,
        required=True,
        help="Location of the steps directory",
    )
    parser.add_argument(
        "--jobstore_dir",
        metavar="PATH",
        type=str,
        required=True,
        help="Location of the jobstore directory",
    )
    parser.add_argument(
        "--input_dir",
        metavar="PATH",
        type=str,
        required=True,
        help="Location of the input directory",
    )
    parser.add_argument(
        "--output_dir",
        metavar="PATH",
        type=str,
        required=True,
        help="Location of the output directory",
    )
    parser.add_argument(
        "--slurm",
        metavar="FILE",
        type=str,
        required=True,
        help="YAML file describing the SLURM resources",
    )
    return parser


def cactus_job_command_name(line):
    """Gathering information according to the cactus command line.

    Args:
        @line: string containing a line read from the file

    Returns:
        a dictionary (command, id, variable_name, jobstore) informing:
            - command: a string showing the name of the binary
            - id: An unique ID for the command line
            - variable_name: a unique value for the given command line
            - jobstore: The jobstore number if exist
        or None; otherwise
    """
    if isinstance(line, str) and len(line) > 0:
        command = line.split()[0]
        jobstore = None

        if "cactus" in command:
            jobstore = line.split()[1]

            if "preprocess" in command:
                info_id = (
                    re.search("--inputNames (.*?) --", line).group(1).replace(" ", "_")
                )
                variable_name = (
                    f"{command.replace('-', '_')}_{jobstore}_{info_id}".upper()
                )

            elif "blast" in command or "align" in command:
                info_id = re.findall("--root (.*)$", line)[0].split()[0]
                variable_name = (
                    f"{command.replace('-', '_')}_{jobstore}_{info_id}".upper()
                )

        elif command == "hal2fasta":
            info_id = re.findall("(.*) --hdf5InMemory", line)[0].split()[-1]
            variable_name = f"{command}_{info_id}".upper()

        elif command == "halAppendSubtree":
            parent_name = line.split()[3]
            root_name = line.split()[4]
            info_id = f"{parent_name}_{root_name}"
            variable_name = f"{command}_{parent_name}_{root_name}".upper()

        return {
            "command": command,
            "id": info_id,
            "variable": re.sub("[^a-zA-Z0-9]", "_", variable_name),
            "jobstore": jobstore,
        }

    return None


def parse_yaml(filename):
    """YAML parser.

    Args:
        filename: Filename path

    Returns:
        YAML content or None otherwise
    """

    with open(filename, encoding="utf-8") as file:
        try:
            return yaml.load(file, Loader=SafeLoader)
        except yaml.YAMLError as err:
            print(err)
            sys.exit(1)

    return None


def check_slurm_resources_info(content, keys):
    """Check if the given slurm configuration file is correct.

    Args:
        @content: the dictionary containing the content from the slurm configuration file
        @keys: the keys that must be in the content

    Returns:
        None if everything is correct or a list of errors otherwise.
    """
    errors = []

    if not isinstance(content, dict):
        errors.append(f"{content} is not a directory")

    for key in keys:
        if not key in content:
            errors.append(f'key "{key}" is missing')

    if len(errors) == 0:
        return None

    return errors


###################################################################
###               CACTUS-BATCHER  PARSING STEP                   ##
###################################################################


def parse(
    read_func,
    symlink_dir,
    root_dir,
    script_dirs,
    log_dir,
    task_type,
    stop_condition,
    ext="dat",
):
    """Main function to parse the output file of Cactus-prepare.

    Args:
        @read_func: pointer to the function that yields input lines
        @symlink_dir: list of directories (as source) for symlink creation
        @root_dir: the directory to save parser's output
        @task_type: type of the given task
        @stop_condition: the condition to stop this parser
        @script_dirs: list of extra directories to be created inside of @root_dir
    """

    # dict to point to parsed files
    parsed_files = {}

    # Preamble - create links and directories needed to execute Cactus at
    # @root_dir
    if task_type != "alignments":

        # For the alignment step, these links must be created inside of each round  directory,
        # which is done inside of the while loop below
        create_symlinks(src_dirs=symlink_dir, dest=root_dir)

        # create log directory at root_dir
        mkdir(f"{root_dir}/{log_dir}", force=True)

        # create script directory at root_dir
        for script_dir in script_dirs.values():
            mkdir(f"{root_dir}/{script_dir}", force=True)

    while True:
        # get the next line
        line = next(read_func, None)

        # job done: NONE
        if not line:
            break

        # strip the line
        line = line.strip()

        # empty line, get the next one ...
        if not line:
            continue

        # job done for task_name
        if stop_condition and line.startswith(stop_condition):
            break

        if task_type == "preprocessor":

            # define the correct filenames to write the line
            parsed_files[
                "all"
            ] = f"{root_dir}/{script_dirs['all']}/all-{task_type}.{ext}"

        elif task_type == "alignments":

            # preamble - create a new round directory
            if line.startswith("### Round"):
                round_id = line.split()[-1]
                round_path = f"{root_dir}/{round_id}"

                # create script directory at root_dir
                for script_dir in script_dirs.values():
                    mkdir(f"{round_path}/{script_dir}", force=True)

                # create log directory at root_dir
                mkdir(f"{round_path}/{log_dir}", force=True)

                # create links needed for execution
                create_symlinks(src_dirs=symlink_dir, dest=round_path)

                # go to the next line
                continue

            # sanity check
            assert "round_path" in locals()

            # extract line info
            info = cactus_job_command_name(line)

            # update filenames to write the line
            parsed_files[
                "all"
            ] = f"{round_path}/{script_dirs['all']}/{info['id']}.{ext}"

        # update filenames to write the line
        elif task_type == "merging":

            # get parent and root node from the command line
            parsed_files[
                "all"
            ] = f"{root_dir}/{script_dirs['all']}/all-{task_type}.{ext}"

        # write the line in the correct files
        for filename in parsed_files.values():
            append(filename=filename, line=line)


###################################################################
###                  SLURM BASH SCRIPT CREATOR                   ##
###################################################################


def get_slurm_submission(
    job_name,
    variable_name,
    work_dir,
    log_dir,
    partition,
    gpus,
    cpus,
    command,
    dependencies,
    script_filename,
    singularity=True,
):
    """Prepare a Slurm string call.

    Args:
        @name: name for the Slurm job
        @word_dir: Location where the slurm should to to run the command
        @log_dir: Path Cactus' log
        @partition: Slurm partition name to dispatch the job
        @gpus: Amount of GPUs to run the job
        @cpus: Amount of CPUs to run the job
        @command: Command to be wrapped by Slurm
        @dependencies: list of Job IDs that this job depends on
        @singularity: True if @commands should run via singularity
    """

    # sbatch command line
    sbatch = [f"TASK_{variable_name}=$(sbatch", "--parsable", "--requeue"]
    sbatch.append(f"-J {job_name}")

    if work_dir is not None:
        sbatch.append(f"-D {work_dir}")

    sbatch.append(f"-o {log_dir}/{job_name}-%j.out")
    sbatch.append(f"-e {log_dir}/{job_name}-%j.err")
    sbatch.append(f"-p {partition}")

    if gpus is not None and gpus != "None":
        sbatch.append(f"--gres=gpu:{gpus}")

    if cpus is not None:
        sbatch.append(f"-c {cpus}")

    if dependencies is not None and len(dependencies) > 0:
        all_deps = ":$".join(["TASK_" + dep for dep in dependencies])
        sbatch.append(f"--dependency=afterok:${all_deps}")

    # define singularity
    if singularity:

        # get image PATH from environment variable
        image = os.environ.get("CACTUS_IMAGE")

        # for GPU usage, grab another image
        if gpus is not None and gpus != "None":
            image = f"--nv {os.environ.get('CACTUS_GPU_IMAGE')}"

        # wrap the commands to use singularity
        command = f"singularity run {image} {command}"

    # real wrapped job
    job_filename = script_filename.replace(".sh", "-job.sh")
    jobs = ["source ~/.google_env_loader.sh", command]

    if os.environ.get("CACTUS_USAGE_LOGGER") is not None:
        gpu_option = "" if gpus is None else "-g"
        jobs.insert(
            1,
            f"bash ~/git/thiago-ebi-tools/bin/usage.sh {gpu_option} -o {log_dir}/{job_name}.usage &",
        )

    # write jobs to the file
    append(filename=job_filename, line="\n\n".join(jobs))

    # wrap the commands for SLURM
    sbatch.append(f'--wrap "source {job_filename}")')

    # store it in the individual bash script
    append(filename=script_filename, line=" ".join(sbatch))


def slurmify(
    root_dir,
    script_dirs,
    log_dir,
    resources,
    initial_dependencies,
    ext="dat",
):
    """Wraps each command line into a Slurm job.

    Args:
        @root_dir: Location of the cactus task
        @script_dirs: Directory to read data and create scripts
        @log_dir: Log path for Cactus call
        @resources: Slurm resources information
        @initial_dependencies: essential dependencies set before
        @ext: Extension for the files that contains the command lines
    """

    # get list of filenames
    filenames = next(os.walk(f"{root_dir}/{script_dirs['all']}"), (None, None, []))[2]

    # list of variable names that serve as dependencies for the next batch
    extra_dependencies = []

    for filename in filenames:

        # sanity check
        aggregated_bashscript_filename, file_extension = os.path.splitext(filename)
        if ext not in file_extension:
            continue

        # create aggregated bash script
        aggregated_bashscript_filename = (
            f"{root_dir}/{script_dirs['all']}/{aggregated_bashscript_filename}.sh"
        )
        create_bash_script(filename=aggregated_bashscript_filename)

        # dependency SLURM variable
        intra_dependencies = list(initial_dependencies)

        for commands in read_file(
            filename=f"{root_dir}/{script_dirs['all']}/{filename}"
        ):
            # just in case more than one command per line
            for line in commands.split(";"):
                # remove rubbish
                line = line.strip()

                # extract line info from the current command line to create key
                # info for SLURM
                info = cactus_job_command_name(line)

                # set Cactus log file for Toil outputs
                if (
                    info["command"] != "halAppendSubtree"
                    and info["command"] != "hal2fasta"
                ):
                    line = (
                        line
                        + f" --logFile {root_dir}/{log_dir}/{info['command']}-{info['id']}.log"
                    )

                # update the extra dependency between task types
                extra_dependencies.append(info["variable"])
                if (
                    info["command"] == "cactus-blast"
                    or info["command"] == "cactus-align"
                ):
                    extra_dependencies.pop()

                # enabling restart option for Cactus if a jobstore folder
                # exists
                if info["jobstore"] is not None:
                    if os.path.isdir(f"{root_dir}/{info['jobstore']}"):
                        line = f"{line} --restart"

                # create individual bash script
                individual_bashscript_filename = f"""
                    {root_dir}/{script_dirs['separated']}/{info['command']}-{info['id']}.sh
                """
                create_bash_script(filename=individual_bashscript_filename)

                # get the SLURM string call
                get_slurm_submission(
                    job_name=f"{info['command']}-{info['id']}",
                    variable_name=info["variable"],
                    work_dir=f"{root_dir}",
                    log_dir=f"{root_dir}/{log_dir}",
                    script_filename=individual_bashscript_filename,
                    partition=f"{resources[info['command']]['partition']}",
                    gpus=resources[info["command"]]["gpus"],
                    cpus=resources[info["command"]]["cpus"],
                    command=f"{line.strip()}",
                    dependencies=intra_dependencies,
                    singularity=True,
                )

                # update the intra dependency list between info['command']
                if (
                    info["command"] == "halAppendSubtree"
                    or info["command"] == "cactus-blast"
                    or info["command"] == "cactus-align"
                ):
                    intra_dependencies.clear()
                    intra_dependencies.append(info["variable"])

                # store it in the aggregated bash script
                append(
                    filename=aggregated_bashscript_filename,
                    line=f"source {individual_bashscript_filename}",
                )

    # dependencies for the next batch
    return extra_dependencies


###################################################################
###          SLURM  WORKFLOW BASH SCRIPT CREATOR                 ##
###################################################################


def create_workflow_script(
    root_dir: Union[str, None], task_type: str, script_dir: str, workflow_filename: str
) -> None:
    """Create Cactus pipeline using Slurm dependencies.

    Args:
        @root_dir: root directory where @task_type's bash local scripts are
        @task_type: type of the given task
        @script_dir: the directory where @task_type's scripts are
        @workflow_filename: the name of the bash script that contains the Cactus pipeline
    """

    # adding preprocess
    append(filename=workflow_filename, line=f"\n### - {task_type} step\n")

    # get path path for all-{}.sh bash script
    path = f"{root_dir}/{script_dir}"
    filenames = next(os.walk(path), (None, None, []))[2]

    # check all files
    for filename in filenames:

        # update filename path
        script = f"{path}/{filename}"

        # filtering files that aren't executable
        if os.path.isfile(script) and not os.access(script, os.X_OK):
            continue

        append(filename=workflow_filename, line=" ".join(["source", script]))


###################################################################
###                             MAIN                             ##
###################################################################

if __name__ == "__main__":

    ###################################################################
    ###                   PYTHON  ARGPARSE STEP                      ##
    ###################################################################

    # parse the args given
    args = create_argparser().parse_args()

    # get absolute path
    args.steps_dir = os.path.abspath(args.steps_dir)
    args.jobstore_dir = os.path.abspath(args.jobstore_dir)
    args.input_dir = os.path.abspath(args.input_dir)
    args.output_dir = os.path.abspath(args.output_dir)

    ###################################################################
    ###                        SLURM  DATA                           ##
    ###################################################################

    # get SLURM resources
    slurm_config = parse_yaml(filename=args.slurm)

    # sanity check resources
    slurm_key_data = [
        [
            "cactus-preprocess",
            "cactus-align",
            "cactus-blast",
            "hal2fasta",
            "halAppendSubtree",
            "regular",
        ],
        ["gpus", "cpus", "partition"],
    ]

    missing_slurm_data = check_slurm_resources_info(
        content=slurm_config, keys=slurm_key_data[0]
    )
    if missing_slurm_data is not None:
        data = "\n".join(missing_slurm_data)
        raise Exception(f"The following keys are missing in the YAML file:\n{data}")

    for node_type in slurm_config.keys():
        missing_slurm_data = check_slurm_resources_info(
            content=slurm_config[node_type], keys=slurm_key_data[1]
        )
        if missing_slurm_data is not None:
            data = "\n".join(missing_slurm_data)
            raise Exception(
                f"The following keys are missing in the '{node_type}' key:\n{data}"
            )

    # create pointer to the read function
    reader = read_file(args.commands)

    ###################################################################
    ###                          DATA                                ##
    ###################################################################

    # essential data for parsing function
    data = {
        "trigger_parsing": "## Preprocessor",
        "task_order": ["preprocessor", "alignments", "merging"],
        "workflow_script_name": "run_cactus_workflow",
        "jobs": {
            "preprocessor": {
                "task_name": "1-preprocessors",
                "stop_condition": "## Alignment",
                "directories": {
                    "root": args.output_dir,
                    "symlinks": [args.steps_dir, args.jobstore_dir, args.input_dir],
                    "logs": "logs",
                    "scripts": {
                        "all": "scripts/all",
                        "separated": "scripts/separated",
                    },
                    "rounds": [None],
                },
            },
            "alignments": {
                "task_name": "2-alignments",
                "stop_condition": "## HAL merging",
                "directories": {
                    "root": args.output_dir,
                    "symlinks": [args.steps_dir, args.jobstore_dir, args.input_dir],
                    "logs": "logs",
                    "scripts": {
                        "all": "scripts/all",
                        "separated": "scripts/separated",
                    },
                    "rounds": [None],
                },
            },
            "merging": {
                "task_name": "3-merging",
                "stop_condition": None,
                "directories": {
                    "root": args.output_dir,
                    "symlinks": [
                        args.steps_dir,
                        args.jobstore_dir,
                    ],
                    "logs": "logs",
                    "scripts": {
                        "all": "scripts/all",
                        "separated": "scripts/separated",
                    },
                    "rounds": [None],
                },
            },
        },
    }

    ###################################################################
    ###               CACTUS-PREAPRE  PARSING STEP                   ##
    ###################################################################

    # Parsing loop
    while True:

        # get a line from the input file
        raw_line: str = next(reader, "")

        # parsing job done
        if not raw_line:
            break

        # wait...
        if not raw_line.startswith(data["trigger_parsing"]):
            continue

        # starting parsing procedure
        for job in data["task_order"]:

            parse(
                read_func=reader,
                symlink_dir=data["jobs"][job]["directories"]["symlinks"],
                root_dir=f"{data['jobs'][job]['directories']['root']}/{data['jobs'][job]['task_name']}",
                script_dirs=data["jobs"][job]["directories"]["scripts"],
                log_dir=data["jobs"][job]["directories"]["logs"],
                task_type=job,
                stop_condition=data["jobs"][job]["stop_condition"],
            )

    ###################################################################
    ###       UPDATE ALIGNMENT STEP ESSENTIAL DIRECTORIES            ##
    ###################################################################

    # update alignment job information including "script_dir" for each round
    # dir
    job = "alignments"

    # get rounds
    round_dirs = sorted(
        next(
            os.walk(
                f"{data['jobs'][job]['directories']['root']}/{data['jobs'][job]['task_name']}"
            ),
            (None, None, []),
        )[1]
    )
    data["jobs"][job]["directories"]["rounds"] = round_dirs

    ###################################################################
    ###                  SLURM BASH SCRIPT CREATOR                   ##
    ###################################################################

    # list to carry dependencies between job types, e.g., preprocess,
    # alignment, merging
    slurm_job_dependencies = []

    for job in data["task_order"]:
        directories = data["jobs"][job]["directories"]
        for round_dir in directories["rounds"]:

            # create SLURM batches jobs
            slurm_job_dependencies = slurmify(
                root_dir=(
                    f"{directories['root']}/{data['jobs'][job]['task_name']}"
                    if round_dir is None
                    else f"{directories['root']}/{data['jobs'][job]['task_name']}/{round_dir}"
                ),
                script_dirs=directories["scripts"],
                log_dir=directories["logs"],
                resources=slurm_config,
                initial_dependencies=slurm_job_dependencies,
            )

    ###################################################################
    ###         FINAL CACTUS PIPELINE BASH SCRIPT USING SLURM        ##
    ###################################################################

    # create a new bash script file there
    workflow_scripts = f"{args.output_dir}/{data['workflow_script_name']}.sh"
    create_bash_script(filename=workflow_scripts)

    for job in data["task_order"]:
        dir_: dict[str, Any] = data["jobs"][job]["directories"]
        for round_dir in dir_["rounds"]:

            create_workflow_script(
                root_dir=(
                    f"{dir_['root']}/{data['jobs'][job]['task_name']}"
                    if round_dir is None
                    else f"{dir_['root']}/{data['jobs'][job]['task_name']}/{round_dir}"
                ),
                task_type=job,
                script_dir=dir_["scripts"]["all"],
                workflow_filename=workflow_scripts,
            )
