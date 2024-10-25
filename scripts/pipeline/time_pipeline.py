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

""" Script to calculate real time duration of a pipeline """

import sys
import re
import argparse
from typing import Dict, Any, Union
from datetime import datetime, timedelta

from sqlalchemy import create_engine, text

def die_with_help() -> None:
    """ print helptext and exit """

    helptext = """

time_pipeline.py -url <database_url> [options]

-url | --database_url       URL for pipeline database
-a   | --analyses_pattern   include only some analyses (format: "1", "1..10", "1,2,3")
-l   | --analyses_list      file containing list of logic_names
-g   | --gap_list           print list summary of gaps found
-h   | --help               this help menu

    """
    die_with_message(helptext)

def die_with_message(message: str) -> None:
    """ print message and exit """
    print(message)
    sys.exit(1)

def formulate_condition(analyses_pattern: str, analyses_list: str) -> str:
    """ formulate WHERE SQL condition from analyses_pattern """
    condition = ''
    if analyses_pattern:
        a_range = re.match(r'(\d+)\.\.(\d+)', analyses_pattern)
        if a_range:
            condition = f" WHERE analysis_id BETWEEN {a_range.group(1)} AND {a_range.group(2)}"
        else:
            condition = f" WHERE analysis_id IN ({analyses_pattern})"
    elif analyses_list:
        try:
            with open(analyses_list) as f:
                logic_names = [f"'{x.strip()}'" for x in f.readlines()]
                if len(logic_names) < 1:
                    die_with_message(f"File '{analyses_list}' is empty")
                condition = f" WHERE logic_name IN ({','.join(logic_names)})"
        except FileNotFoundError:
            die_with_message(f"Cannot find analyses_list file: {analyses_list}")

    return condition


def parse_args(argv: list) -> argparse.Namespace:
    """ parse the command-line arguments """
    parser = argparse.ArgumentParser()
    parser.add_argument('-url', '--database_url')
    parser.add_argument('-a', '--analyses_pattern')
    parser.add_argument('-l', '--analyses_list')
    parser.add_argument('-g', '--gap_list', action='store_true', default=False)
    opts = parser.parse_args(argv[1:])

    if not opts.database_url:
        die_with_help()

    if opts.analyses_pattern and opts.analyses_list:
        print("--analyses_pattern and --analyses_list are mutually exclusive\n")
        die_with_help()

    return opts


def main(opts: argparse.Namespace) -> None:
    """ main """

    # figure out analyses_pattern
    condition = formulate_condition(opts.analyses_pattern, opts.analyses_list)

    # set up db connection and fetch role data
    engine = create_engine(opts.database_url, future=True)
    connection = engine.connect()
    sql = "SELECT role_id, logic_name, when_started, when_finished FROM role"
    sql += " JOIN analysis_base USING(analysis_id)"
    sql += condition + " ORDER BY role_id"
    result = connection.execute(text(sql))

    # loop through roles and find runtime gaps
    runtime_gaps = []
    mins15 = timedelta(minutes=15)
    prev_role = {}
    now = datetime.now()
    pipeline_start = '' # type: Union[Any, datetime]
    pipeline_total_runtime = timedelta()
    for result_mapping in result.mappings():
        role = dict(result_mapping)

        # Initalize start/finish times
        if pipeline_start == '':
            pipeline_start = role['when_started']
            prev_role = role

        # Skip this if the pipeline is stil running
        elif prev_role['when_finished'] is not None:

            # Gap detection
            if role['when_started'] > prev_role['when_finished']:
                this_gap = role['when_started'] - prev_role['when_finished']
                if this_gap > mins15:
                    gap_desc = {
                        'role_id_a': prev_role['role_id'],
                        'analysis_a': prev_role['logic_name'],
                        'role_id_b': role['role_id'],
                        'analysis_b': role['logic_name'],
                        'gap': this_gap
                    }
                    runtime_gaps.append(gap_desc)

            if (role['when_finished'] is None) or (role['when_finished'] > prev_role['when_finished']):
                prev_role = dict(role)

        pipeline_total_runtime += (role['when_finished'] or now) - role['when_started']

    if pipeline_start == '':
        print("Pipeline hasn't started yet !")
        sys.exit(1)

    # get overall timings
    pipeline_finish = prev_role['when_finished']
    pipeline_gross_time = (pipeline_finish or now) - pipeline_start
    gaps_total = timedelta(minutes=0)
    for gap in runtime_gaps:
        gaps_total += gap['gap']
    pipeline_net_time = pipeline_gross_time - gaps_total
    average_running_jobs = pipeline_total_runtime.total_seconds() / pipeline_gross_time.total_seconds()

    # print summaries
    print("\nPipeline duration summary:")
    if pipeline_finish:
        print(f"\t- began at {pipeline_start} and ended at {pipeline_finish}")
    else:
        print(f"\t- began at {pipeline_start} and still running")
    print(f"\t- {pipeline_gross_time} including runtime gaps")
    print(f"\t- {pipeline_net_time} excluding runtime gaps")
    print(f"\t- {pipeline_total_runtime} total runtime")
    print(f"\t- {average_running_jobs:.1f} running jobs on average")
    print(f"\t- {len(runtime_gaps)} gaps detected, totalling {gaps_total}")

    if opts.gap_list:
        print_gaps(runtime_gaps)

    print()

def print_gaps(runtime_gaps: list) -> None:
    """print the runtime gaps identified above"""
    print("\nGaps list:")
    for gap in runtime_gaps:
        analysis_str = ''
        if gap['analysis_a'] == gap['analysis_b']:
            analysis_str = f"during {gap['analysis_a']}"
        else:
            analysis_str = f"between {gap['analysis_a']} and {gap['analysis_b']}"
        print(
            f"\t- {gap['gap']} between role_ids {gap['role_id_a']} and {gap['role_id_b']} ({analysis_str})"
        )

if __name__ == "__main__":
    main(parse_args(sys.argv))
