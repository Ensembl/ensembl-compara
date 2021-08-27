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

"""Json parameter wrapping script to make everything compatible with everything"""

import argparse
import os
import shlex
import subprocess
import sys

import jsonpickle


def parse_json(json_string):
    """Parse JSON string

    Args:
        json_string: JSON format string

    Returns:
        A list of parameter style arguments

    Raises:
        ValueError: If json_args is not a valid json string

    """

    return jsonpickle.decode(json_args)


def run_script(script, json_string):
    """Execute program with parameters

    Args:
        json_string: JSON format string
        script     : Executable script

    Returns:
        The executed script output

    Raises:
        Exception: If script does not execute
    """

    py_obj = parse_json(json_string)
    params = " ".join("-{!s} {!r}".format(key, val) for (key, val) in py_obj.items())
    args = shlex.split(params)
    p = subprocess.Popen(args, shell=True, stdout=subprocess.PIPE)
    output, stderr = p.communicate()

    p.wait()
    if p.returncode != 0:
        out = "stdout={}".format(output)
        out += ", stderr={}".format(stderr)
        raise RuntimeError(
            "Command {} exited {}: {}".format(call, process.returncode, out)
        )
    else:
        print("Successfully ran: {}".format(" ".join(call)))

    return output.strip()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--script")
    parser.add_argument("-s", "--json_string")
    opts = parser.parse_args()

    json_string = opts.json_string
    script = opts.script
    run_script(script, json_string)
