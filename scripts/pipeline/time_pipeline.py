#!/usr/bin/python3

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
from typing import Dict, Any
from datetime import timedelta

from sqlalchemy import create_engine

def die_with_help() -> None:
    """ print helptext and exit """

    helptext = """

time_pipeline.py -url <database_url> [options]

-url | --database_url       URL for pipeline database
-a   | --analyses_pattern   include only some analyses (format: "1", "1..10", "1,2,3")
-g   | --gap_list           print list summary of gaps found
-h   | --help               this help menu

    """
    print(helptext)
    sys.exit(1)


def row2dict(row: dict) -> dict:
    """ convert an sqlalchemy row to a python dictionary """
    d = {}
    for key in row.keys():
        d[key] = row[key]
    return d

def formulate_condition(analyses_pattern: str) -> str:
    """ formulate WHERE SQL condition from analyses_pattern """
    condition = ''
    if analyses_pattern:
        a_range = re.match(r'(\d+)\.\.(\d+)', analyses_pattern)
        if a_range:
            condition = " WHERE analysis_id BETWEEN %s AND %s" % (a_range.group(1), a_range.group(2))
        else:
            condition = " WHERE analysis_id IN (%s)" % analyses_pattern
    return condition

def main(argv: list) -> None:
    """ main """
    parser = argparse.ArgumentParser()
    parser.add_argument('-url', '--database_url')
    parser.add_argument('-a', '--analyses_pattern')
    parser.add_argument('-g', '--gap_list', action='store_true', default=False)
    opts = parser.parse_args(argv[1:])

    if not opts.database_url:
        die_with_help()

    # figure out analyses_pattern
    condition = formulate_condition(opts.analyses_pattern)

    # set up db connection and fetch role data
    engine = create_engine(opts.database_url)
    connection = engine.connect()
    sql = "SELECT role_id, logic_name, when_started, when_finished FROM role"
    sql += " JOIN analysis_base USING(analysis_id)"
    sql += condition + " ORDER BY role_id"
    role_list = connection.execute(sql)

    # loop through roles and find runtime gaps
    runtime_gaps = []
    mins15 = timedelta(minutes=15)
    prev_role = {} # type: Dict[str, Any]
    pipeline_start = ''
    for role in role_list:
        try:
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
        except KeyError:
            pipeline_start = role['when_started']
            prev_role = row2dict(role)

        if role['when_finished'] > prev_role['when_finished']:
            prev_role = row2dict(role)

    # get overall timings
    pipeline_finish = prev_role['when_finished']
    pipeline_gross_time = pipeline_finish - pipeline_start
    gaps_total = timedelta(minutes=0)
    for gap in runtime_gaps:
        gaps_total += gap['gap']
    pipeline_net_time = pipeline_gross_time - gaps_total

    # print summaries
    print("\nPipeline duration summary:")
    print("\t- began at %s and ended at %s" % (pipeline_start, pipeline_finish))
    print("\t- %s including runtime gaps" % pipeline_gross_time)
    print("\t- %s excluding runtime gaps" % pipeline_net_time)
    print("\t- %d gaps detected, totalling %s" % (len(runtime_gaps), gaps_total))

    if opts.gap_list:
        print("\nGaps list:")
        for gap in runtime_gaps:
            analysis_str = ''
            if gap['analysis_a'] == gap['analysis_b']:
                analysis_str = 'during %s' % gap['analysis_a']
            else:
                analysis_str = 'between %s and %s' % (gap['analysis_a'], gap['analysis_b'])
            print(
                "\t- %s between role_ids %d and %d (%s)" %
                (gap['gap'], gap['role_id_a'], gap['role_id_b'], analysis_str)
            )

    print()

if __name__ == "__main__":
    main(sys.argv)
