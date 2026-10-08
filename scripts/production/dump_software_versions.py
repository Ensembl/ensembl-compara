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
"""Dump Compara software version information."""

from argparse import ArgumentParser
import datetime
import json
import os
from pathlib import Path
import subprocess
from string import Template
from textwrap import dedent


def main() -> None:
    """Main function of script."""

    version_report_template = Template(
        dedent(
            """\
        # Software version report

        - Software config file: ${software_config_file}
        - Time: ${timestamp}

        """
        )
    )

    version_command_template = Template(
        dedent(
            """\
        Command ${command_num}:
        ```
        ${command}
        ```

        Command ${command_num} output:
        ```
        ${command_output}
        ```

        """
        )
    )

    parser = ArgumentParser(description=__doc__)
    parser.add_argument(
        "-i",
        "--software-config-file",
        required=True,
        help="Software config JSON file.",
        )
    parser.add_argument(
        "-o",
        "--output-file",
        required=True,
        help="Output software version info Markdown file.",
    )

    args = parser.parse_args()

    software_config_file_path = Path(args.software_config_file)
    out_file_path = Path(args.output_file)

    with open(software_config_file_path, encoding="utf-8") as in_file_obj:
        software_config = json.load(in_file_obj)

    software_base_paths = {
        "linuxbrew_home": os.environ["LINUXBREW_HOME"],
    }

    for config_key in ("hps_dir", "renv_dir", "warehouse_dir"):
        if config_key in software_config:
            software_base_paths[config_key] = software_config.pop(config_key)

    timestamp = datetime.datetime.now(tz=datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    version_report_text = version_report_template.substitute(
        software_config_file=software_config_file_path, timestamp=timestamp,
    )

    with open(out_file_path, mode="w", encoding="utf-8") as out_file_obj:
        out_file_obj.write(version_report_text)

        for config_key, config_rec in software_config.items():
            if not config_rec:
                continue

            commands = []
            if "version_command" in config_rec:
                if "version_commands" in config_rec:
                    raise ValueError(
                        f"'{config_key}' can have a 'version_command' or 'version_commands', but not both"
                    )
                commands = [config_rec["version_command"]]
            elif "version_commands" in config_rec:
                commands = config_rec["version_commands"]
            if not commands:
                continue

            out_file_obj.write(f"### {config_key}\n\n")
            for command_num, command in enumerate(commands, start=1):
                for software_base_config_key, software_base_path in software_base_paths.items():
                    command = command.replace(f"##{software_base_config_key}##", software_base_path)
                # pylint: disable-next=subprocess-run-check
                process = subprocess.run(
                    command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
                )
                command_output = process.stdout.rstrip()

                version_command_text = version_command_template.substitute(
                    config_key=config_key,
                    command_num=command_num,
                    command=command,
                    command_output=command_output,
                )
                out_file_obj.write(version_command_text)


if __name__ == "__main__":
    main()
