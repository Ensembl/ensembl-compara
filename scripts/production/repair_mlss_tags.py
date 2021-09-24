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
"""Repairs MLSS tags that may have the wrong value, may be missing, or belong to undefined MLSSs.

The Method Link Species Set (MLSS) tags supported are:
    * `max_align`
    * `msa_mlss_id`

Examples::

    $ python repair_mlss_tags.py --max_align \
        --url mysql://ensadmin:${ENSADMIN_PSW}@mysql-ens-compara-prod-6:4616/ensembl_compara_metazoa_51_104

    $ python repair_mlss_tags.py --msa_mlss_id \
        --url mysql://ensadmin:${ENSADMIN_PSW}@mysql-ens-compara-prod-5:4615/ensembl_compara_plants_51_104

    $ python repair_mlss_tags.py --url $(cp1-w details url)ensembl_compara_104 --msa_mlss_id --max_align

"""

from argparse import ArgumentParser

from ensembl.compara.db import DBConnection


EXPECTED_VALUES_SQL = {
    'max_align': """
        SELECT method_link_species_set_id AS mlss_id, MAX(dnafrag_end - dnafrag_start) + 2 AS value
        FROM constrained_element
        GROUP BY method_link_species_set_id
        UNION
        SELECT method_link_species_set_id AS mlss_id, MAX(dnafrag_end - dnafrag_start) + 2 AS value
        FROM genomic_align
        GROUP BY method_link_species_set_id;
    """,
    'msa_mlss_id': """
        SELECT mlss1.method_link_species_set_id AS mlss_id, mlss2.method_link_species_set_id AS value
        FROM method_link_species_set mlss1
        JOIN method_link_species_set mlss2 ON mlss1.species_set_id = mlss2.species_set_id
        JOIN method_link ml1 ON mlss1.method_link_id = ml1.method_link_id
        JOIN method_link ml2 ON mlss2.method_link_id = ml2.method_link_id
        WHERE (ml1.class = "ConservationScore.conservation_score"
            OR ml1.class = "ConstrainedElement.constrained_element")
        AND (ml2.class = "GenomicAlignBlock.multiple_alignment" OR ml2.class LIKE "GenomicAlignTree.%%")
        AND ml1.type NOT LIKE "pGERP%%"
        AND ml2.type NOT LIKE "pEPO%%";
    """
}


def repair_mlss_tag(dbc: DBConnection, mlss_tag: str) -> None:
    """Repairs the given MLSS tag in the database, recomputing the expected values.

    It uses the predefined query in `EXPECTED_VALUES_SQL` for the given MLSS tag to extract the
    expected value for each MLSS id. It also adds any missing tags as well as removes any rows that
    may contain an invalid MLSS id.

    Args:
        dbc: Compara database connection handler.
        mlss_tag: MLSS tag as found in the ``method_link_species_set_tag`` table.

    """
    with dbc.connect() as connection:
        # Get the MLSS tags in method_link_species_set_tag table
        mlss_tag_values = connection.execute(f"SELECT method_link_species_set_id AS mlss_id, value "
                                             f"FROM method_link_species_set_tag WHERE tag = '{mlss_tag}';")
        mlss_tags = {row.mlss_id: row.value for row in mlss_tag_values.fetchall()}
        # Extract the expected tag value based on the source data
        expected_values = connection.execute(EXPECTED_VALUES_SQL[mlss_tag])
        # Check that each tag has the correct value, fixing those that do not, and add any missing tags
        for row in expected_values:
            if row.mlss_id in mlss_tags:
                # NOTE: due to internal conversions, we need to ensure both sides have the same time
                if str(mlss_tags[row.mlss_id]) != str(row.value):
                    connection.execute(f'UPDATE method_link_species_set_tag SET value = {row.value} '
                                       f'WHERE method_link_species_set_id = {row.mlss_id} '
                                       f'    AND tag = "{mlss_tag}";')
                    print(f"Repaired MLSS tag '{mlss_tag}' for MLSS id '{row.mlss_id}'")
                del mlss_tags[row.mlss_id]
            else:
                connection.execute(f'INSERT INTO method_link_species_set_tag '
                                   f'VALUES ({row.mlss_id}, "{mlss_tag}", {row.value});')
                print(f"Added missing MLSS tag '{mlss_tag}' for MLSS id '{row.mlss_id}'")
        # Delete those MLSS tags that do not match any MLSS in method_link_species_set table
        for mlss_id in mlss_tags.keys():
            connection.execute(f'DELETE FROM method_link_species_set_tag '
                               f'WHERE method_link_species_set_id = {mlss_id};')
            print(f"Deleted unexpected MLSS tag '{mlss_tag}' for MLSS id '{mlss_id}'")


if __name__ == '__main__':
    parser = ArgumentParser(description='Repairs the requested MLSS tag(s).')
    parser.add_argument('--url', required=True, help='URL to the Compara database')
    parser.add_argument('--max_align', action='store_true', help='Fix the "max_align" MLSS tag')
    parser.add_argument('--msa_mlss_id', action='store_true', help='Fix the "msa_mlss_id" MLSS tag')
    args = parser.parse_args()
    if args.max_align or args.msa_mlss_id:
        compara_dbc = DBConnection(args.url)
        if args.max_align:
            repair_mlss_tag(compara_dbc, 'max_align')
        if args.msa_mlss_id:
            repair_mlss_tag(compara_dbc, 'msa_mlss_id')
    else:
        print('No repair option has been selected: Nothing to do')
