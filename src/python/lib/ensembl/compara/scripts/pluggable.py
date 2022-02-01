#!/usr/bin/env python3

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

from argparse import ArgumentError
import logging
import shlex
import subprocess
from typing import List, Optional

import argschema
import jsonpickle
from marshmallow import post_load


logging.getLogger('root').setLevel('ERROR')


class ParamsSchema(argschema.schemas.DefaultSchema):
    json = argschema.fields.Str(default='', description='Input parameters string in JSON format')
    hash = argschema.fields.Dict(default={}, description='Input parameters dictionary')


class InputSchema(argschema.ArgSchema):
    script = argschema.fields.Str(required=True, description='Script to execute')
    timeout = argschema.fields.Int(required=False, description='Maximum time the script can run (in seconds)')
    params = argschema.fields.Nested(ParamsSchema)

    @post_load
    def make_cmd(self, data, **kwargs):
        cmd = [data['script']]
        if (data['params']['json']):
            if (data['params']['hash']):
                raise ArgumentError("Allowed either 'params.json' or 'params.hash', but not both")
            parameters = jsonpickle.decode(data['params']['json'])
        else:
            parameters = data['params']['hash']
        args = []
        for key, value in parameters.items():
            if key:
                cmd.append(f"--{key} {value}")
            else:
                args.append(f"{value}")
        data['cmd'] = shlex.split(' '.join(cmd + args))
        return data


def run_script(cmd: List[str], timeout: Optional[int] = None) -> str:
    print(f"\ncmd: {cmd}")
    try:
        result = subprocess.run(cmd, capture_output=True, check=True, text=True, timeout=timeout)
    except subprocess.CalledProcessError as exc:
        msg = f"Command '{exc.cmd}' returned non-zero exit status {exc.returncode}"
        if exc.stdout:
            msg += f"\n  StdOut: {exc.stdout}"
        if exc.stderr:
            msg += f"\n  StdErr: {exc.stderr}"
        raise RuntimeError(msg)
    return result.stdout.strip()


if __name__ == '__main__':
    mod = argschema.ArgSchemaParser(schema_type=InputSchema, output_schema_type=ParamsSchema)
    print(f"\nargs: {mod.args}")

    if 'timeout' in mod.args:
        output = run_script(mod.args['cmd'], mod.args['timeout'])
    else:
        output = run_script(mod.args['cmd'])

    print(f"\noutput:\n{output}")
    if 'output_json' in mod.args:
        mod.output(jsonpickle.decode(output))
