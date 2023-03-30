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

"""
Locate genome dumps of a collection or a species set on disk.
Example:
    $ python fetch_genomes_from_db.py -u mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_master -c pig_breeds -o test.tsv -d /hps/nobackup/flicek/ensembl/compara/shared/genome_dumps/vertebrates
"""

import sys
import argparse
import csv
from os import path
from sqlalchemy.engine.row import Row
from sqlalchemy import create_engine, text

# Parse command line arguments:
parser = argparse.ArgumentParser(
    description='Locate genomes of a species set/collection in the dump directory.')
parser.add_argument('-u', metavar='db_URL', type=str, help="Compara master db URL.", required=True)
parser.add_argument(
    '-d', metavar='dump_dir', type=str, help="Genome dump directory.", required=True)
parser.add_argument(
    '-s', metavar='ssid', type=str, help="Species set id.", required=False, default=None)
parser.add_argument(
    '-c', metavar='cid', type=str, help="Collection id.", required=False, default=None)
parser.add_argument(
    '-o', metavar='output', type=str, help="Output CSV.", required=True)


def _dir_revhash(gid: int) -> str:
    """Build directory hash from genome db id."""
    dir_hash = list(reversed(str(gid)))
    dir_hash.pop()
    return path.join(*dir_hash)


def _build_dump_path(row: Row) -> str:
    gcomp = ""
    if row.genome_component is not None:
        gcomp = f"comp{row.genome_component}."
    gpath = path.join(args.d, _dir_revhash(row.genome_db_id), f"{row.name}.{row.assembly}.{gcomp}soft.fa")
    return gpath


if __name__ == '__main__':
    args = parser.parse_args()

    db_url = args.u
    ss_id = args.s
    if ss_id == "":
        ss_id = None
    coll_id = args.c
    if coll_id == "":
        coll_id = None
    engine = create_engine(db_url, future=True)

    if ss_id is None and coll_id is None:
        sys.stderr.write("Either a collection name or a species set id must be specified!\n")
        sys.exit(1)

    if ss_id is not None and coll_id is not None:
        sys.stderr.write("Specify either a collection name or a species set id!\n")
        sys.exit(1)

    ss_query = f"""
        SELECT genome_db_id, genome_db.name, assembly, genebuild,
        strain_name, display_name, genome_component
        FROM species_set JOIN genome_db USING(genome_db_id)
        WHERE species_set_id = {ss_id};
    """
    c_query = f"""
        SELECT genome_db_id, genome_db.name, assembly, genebuild,
        strain_name, display_name, genome_component
        FROM species_set_header JOIN species_set USING(species_set_id)
        JOIN genome_db USING(genome_db_id) WHERE species_set_header.name='{coll_id}'
        AND species_set_header.last_release is NULL
        AND species_set_header.first_release IS NOT NULL;
    """
    query = ss_query
    if coll_id is not None:
        query = c_query

    missing_fas = []
    with engine.connect() as conn, open(args.o, "w") as ofh:
        result = conn.execute(text(query))
        writer = csv.writer(ofh, delimiter="\t", lineterminator="\n")
        for row in result:
            gpath = _build_dump_path(row)
            fa_name = str(row.name) + "_" + str(row.assembly)
            dump_exists = path.exists(gpath)
            if not dump_exists:
                missing_fas.append(gpath)
            writer.writerow([row.genome_db_id, row.name, row.assembly, row.genebuild, row.strain_name,
                             row.display_name, row.genome_component, gpath, dump_exists, fa_name])

    if len(missing_fas) > 0:
        sys.stderr.write("Fatal error! The following genome dumps are missing:\n")
        for p in missing_fas:
            sys.stderr.write(f"{p}\n")
        sys.exit(1)
