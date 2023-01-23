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
Dump rapid release homologies into TSV files.
Example:
    $ python dump_homologies.py -u \
            "mysql://ensro@mysql-ens-compara-prod-2:4522/accipiter_gentilis_compara_105" \
            -r ensembl_compara_references -o test.tsv
"""

import argparse
import csv
from sqlalchemy import create_engine, text

# Parse command line arguments:
parser = argparse.ArgumentParser(
    description='Dump homologies in TSV format.')
parser.add_argument('-u', metavar='db_URL', type=str, help="Species database URL.", required=True)
parser.add_argument(
    '-r', metavar='refdb_name', type=str, help="Name of reference database.", required=True)
parser.add_argument(
    '-o', metavar='output', type=str, help="Output tsv.", required=True)


if __name__ == '__main__':
    args = parser.parse_args()

    ref_db = args.r
    species_db_url = args.u

    engine = create_engine(species_db_url, future=True)

    query = f"""
        SELECT
            gdb1.name AS ref_species,
            gdb1.assembly AS ref_assembly,
            gdb2.name AS query_species,
            gdb2.assembly AS query_assembly,
            gm1.stable_id AS ref_gene_stable_id,
            gm1.display_label AS ref_gene_name,
            gm2.stable_id AS query_gene_stable_id,
            gm2.display_label AS query_gene_name,
            h.description AS homology_type,
            hm2.perc_id AS query_perc_id,
            hm2.perc_cov AS query_perc_cov
        FROM
            homology_member hm1
        JOIN
            homology_member hm2 ON hm1.homology_id = hm2.homology_id
        JOIN
            homology h ON hm1.homology_id = h.homology_id
        JOIN
            {ref_db}.gene_member gm1 ON hm1.gene_member_id = gm1.gene_member_id
        JOIN
            gene_member gm2 ON hm2.gene_member_id = gm2.gene_member_id
        JOIN
            {ref_db}.genome_db gdb1 ON gm1.genome_db_id = gdb1.genome_db_id
        JOIN
            genome_db gdb2 ON gm2.genome_db_id = gdb2.genome_db_id
        JOIN
            {ref_db}.seq_member sm1 ON hm1.seq_member_id = sm1.seq_member_id
        JOIN
            seq_member sm2 ON hm2.seq_member_id = sm2.seq_member_id
        WHERE
            gm1.genome_db_id > gm2.genome_db_id;
    """

    fields = ["ref_species", "ref_assembly", "query_species", "query_assembly", "ref_gene_stable_id",
              "ref_gene_name", "query_gene_stable_id", "query_gene_name",
              "homology_type", "query_perc_id", "query_perc_cov"]

    with open(args.o, "w") as fh:
        writer = csv.DictWriter(fh, fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        with engine.connect() as conn:
            result = conn.execute(text(query))
            for dict_row in result.mappings():
                writer.writerow(dict_row)
