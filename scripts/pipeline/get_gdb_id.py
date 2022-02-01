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

import json

import argschema

from ensembl.database import DBConnection


class InputSchema(argschema.ArgSchema):
    url = argschema.fields.Str(required=True, description='Database URL')
    species = argschema.fields.InputFile(required=True, description='Species JSON file')


if __name__ == '__main__':
    mod = argschema.ArgSchemaParser(schema_type=InputSchema)

    dbc = DBConnection(mod.args['url'])
    with open(mod.args['species']) as f:
        species = json.load(f)
    with dbc.connect() as conn:
        for name in species:
            result = conn.execute(f'SELECT genome_db_id FROM genome_db WHERE name = "{name}" AND '
                                  f'first_release IS NOT NULL AND last_release IS NULL')
            gdb_id = result.first()[0]
            print(f'{{"genome_db_id": {gdb_id}, "species_name": "{name}"}}')
