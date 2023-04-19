#!/usr/bin/env python

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""
This script fetches the number of coding genes and number of coding genes with homologies
against the taxonomically closest reference species.

Usage example::
    python homology_stats_rapid.py\
    -d mysql://ensro@mysql-ens-compara-prod-2:4522/gallus_gallus_gca016699485v1_compara_107\
    -r ensembl_compara_references\
    -t mysql://ensro@mysql-ens-mirror-1:4240/ncbi_taxonomy_109 -o gallus.json
"""

import argparse
import json
from typing import Tuple, List

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Connection
from ensembl.database import DBConnection
from ensembl.ncbi_taxonomy.api.utils import Taxonomy


def parse_arguments() -> argparse.Namespace:
    """
    Parse command line arguments.

    :return: Parsed command line arguments
    """
    parser = argparse.ArgumentParser(
        description="Query gene and homology counts from an Ensembl compara rapid release database."
    )
    parser.add_argument("-d", "--database", required=True, help="Database URL")
    parser.add_argument(
        "-r",
        "--ref_db",
        required=True,
        help="Reference database name. Must be on same server as target database.",
    )
    parser.add_argument(
        "-t", "--tax_db", required=True, help="NCBI taxonomy database URL."
    )
    parser.add_argument(
        "-o", "--output", required=True, help="Output file in JSON format"
    )
    return parser.parse_args()


def get_closest_ref(
    tax_dbc: DBConnection, rr_dbc: Connection, ref_db: str
) -> Tuple[int, str, int, str, int]:
    """
    Get the closest reference for the given rapid release database.

    :param tax_dbc: Taxonomy database connection
    :param rr_dbc: Rapid release database connection
    :param ref_db: Reference database name
    :return: Tuple
    """

    query1 = """
    SELECT name, taxon_id FROM genome_db
    WHERE genome_db_id = 1;
    """

    with rr_dbc.connect() as conn:
        tmp = conn.execute(text(query1)).one()
        query_species, query_taxid = tmp["name"], tmp["taxon_id"]

    query2 = f"""
    SELECT genome_db_id, gdb.taxon_id, gdb.name FROM
    species_set JOIN {ref_db}.genome_db gdb USING(genome_db_id)
    WHERE genome_db_id > 100;
    """

    with rr_dbc.connect() as conn, tax_dbc.session_scope() as session:
        result = conn.execute(text(query2))
        res: List[Tuple] = []
        for dict_row in result.mappings():
            taxid = dict_row["taxon_id"]
            if taxid == query_taxid:
                continue
            anc = Taxonomy.all_common_ancestors(session, query_taxid, taxid)
            res.append((dict_row["genome_db_id"], dict_row["name"], taxid, len(anc)))
    res = sorted(res, key=lambda x: x[3], reverse=True)
    return res[0][0], res[0][1], res[0][2], query_species, query_taxid


def query_rr_database(
    rr_dbc: Connection, genome_db_id: int, ref_db: str
) -> Tuple[int, int]:
    """
    Query the database for the number of homologs and genes.

    :param rr_dbc: Rapid release database connection
    :param genome_db_id: Genome database ID
    :param ref_db: Reference database name
    :return: Tuple containing the number of homologs and genes
    """
    connection: Connection = rr_dbc.connect()

    # Query nr_homologs
    query1 = text(
        f"""
        SELECT COUNT(DISTINCT gene_member_id) AS nr_homologs
        FROM homology
        JOIN homology_member USING(homology_id)
        JOIN {ref_db}.gene_member gm USING(gene_member_id)
        JOIN {ref_db}.genome_db gdb USING(genome_db_id)
        WHERE gm.biotype_group = 'coding'
        AND homology.description LIKE 'homolog_%'
        AND gdb.genome_db_id = {genome_db_id}
    """
    )
    result1 = connection.execute(query1).fetchone()
    nr_homologs = result1["nr_homologs"]

    # Query nr_genes
    query2 = text(
        """
        SELECT COUNT(gene_member_id) AS nr_genes
        FROM gene_member
        JOIN genome_db USING(genome_db_id)
        WHERE gene_member.biotype_group = 'coding'
        AND genome_db_id = 1
    """
    )
    result2 = connection.execute(query2).fetchone()
    nr_genes = result2["nr_genes"]

    return nr_homologs, nr_genes


def write_results_to_json(
    output_file: str,
    data: dict
) -> None:
    """
    Write results to a JSON file.

    :param output_file: Output file name
    :param data: Data to write to JSON
    """

    with open(output_file, "w", encoding="utf-8") as outfile:
        json.dump(data, outfile)


def main() -> None:
    """
    Main function to run the script.
    """
    args = parse_arguments()
    db_url = args.database
    tax_url = args.tax_db
    output_file = args.output
    ref_db = args.ref_db

    tax_dbc = DBConnection(tax_url)
    rr_dbc = create_engine(db_url, future=True)

    ref_gdb, ref_species, ref_taxid, query_species, query_taxid = get_closest_ref(
        tax_dbc, rr_dbc, ref_db
    )

    nr_homologs, nr_genes = query_rr_database(rr_dbc, ref_gdb, ref_db)
    json_data = {
        "query_species": query_species,
        "query_taxon_id": query_taxid,
        "ref_species": ref_species,
        "ref_taxon_id": ref_taxid,
        "nr_query_genes": nr_genes,
        "nr_homologies": nr_homologs,
    }
    write_results_to_json(
        output_file,
        json_data
    )


if __name__ == "__main__":
    main()
