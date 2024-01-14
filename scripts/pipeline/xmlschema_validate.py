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
"""Script to validate XML data file against the given schema.

Unknown options are ignored.
"""

import argparse
import xmlschema


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema", dest="schema_file", metavar="schema_file", required=True,
                        help="Schema file against which to validate.")
    parser.add_argument("data_file", help="XML data file to be validated against the schema.")

    known_args, other_args = parser.parse_known_args()

    schema = xmlschema.XMLSchema(known_args.schema_file)
    schema.validate(known_args.data_file)
