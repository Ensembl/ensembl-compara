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
    -d mysql://ensro@mysql-ens-sta-5:4684/accipiter_gentilis_compara_109\
    -r ensembl_compara_references -o accipiter_gentilis.json
"""

import argparse
import json
from typing import Tuple, List, Dict, Any

from sqlalchemy import text
from sqlalchemy.engine import Connection
from ensembl.database import DBConnection
from ensembl.ncbi_taxonomy.api.utils import Taxonomy


def parse_arguments() -> argparse.Namespace:
    """
    Parse command line arguments.

    Returns:
        Parsed command line arguments
    """
    parser = argparse.ArgumentParser(
        description="Query gene and homology counts from an Ensembl compara rapid release database."
    )
    parser.add_argument("-d", "--database", required=True, help="Database URL")
    parser.add_argument("-x", "--detailed", action="store_true", help="Enable detailed output.")
    parser.add_argument("-i", "--refcoll", action="store_true", help="Save reference collection information.")
    parser.add_argument(
        "-r",
        "--ref_db",
        required=True,
        help="Reference database name. Must be on same server as target database.",
    )
    parser.add_argument("-o", "--output", required=True, help="Output file in JSON format")
    return parser.parse_args()


def get_closest_ref(rr_dbc: DBConnection, ref_db: str) -> Tuple[int, str, int, str, int]:
    """
    Get the closest reference for the given rapid release database.

    Args:
        rr_dbc: Rapid release database connection
        ref_db Reference database name

    Returns:
        Result tuple
    """
    query1 = """
    SELECT name, taxon_id FROM genome_db LIMIT 1;
    """

    with rr_dbc.connect() as conn:
        query_species, query_taxid = conn.execute(text(query1)).one()

    query2 = f"""
    SELECT genome_db_id, gdb.taxon_id, gdb.name
    FROM species_set JOIN {ref_db}.genome_db gdb USING(genome_db_id)
    WHERE genome_db_id > 100;
    """

    with rr_dbc.connect() as conn, rr_dbc.session_scope() as session:
        result = conn.execute(text(query2))
        res: List[Tuple] = []
        for gdb_id, taxid, name in result:
            if taxid == query_taxid:
                continue
            anc = Taxonomy.all_common_ancestors(session, query_taxid, taxid)
            res.append((gdb_id, name, taxid, len(anc)))
    ref_gdb, ref_species, ref_taxid, _ = sorted(res, key=lambda x: (x[3], x[2]), reverse=True)[0]
    return ref_gdb, ref_species, ref_taxid, query_species, query_taxid


def query_rr_database(rr_dbc: Connection, genome_db_id: int, ref_db: str) -> Tuple[int, int]:
    """
    Query the database for the number of homologs and genes.

    Args:
        rr_dbc: Rapid release database connection
        genome_db_id: Genome database ID
        ref_db: Reference database name

    Returns:
        Tuple containing the number of homologs and genes
    """
    with rr_dbc.connect() as connection:
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
            AND genome_db_id <= 100
        """
        )
        result2 = connection.execute(query2).fetchone()
        nr_genes = result2["nr_genes"]

    return nr_homologs, nr_genes


def get_meta_value(rr_dbc: Connection, key: str) -> str:
    """
    Retrieves the value of a meta key from the meta table.

    Args:
        rr_dbc: The database connection object used to query the database.
        key: The key whose corresponding value is to be retrieved.

    Returns:
        The value associated with the specified meta key.

    Raises:
        KeyError: If the key does not exist in the meta table.
    """
    with rr_dbc.connect() as connection:
        query = text(
            f"""
                SELECT meta_value FROM meta
                WHERE meta_key=:meta_key;
                """
        )
        params = {"meta_key": key}
        result = connection.execute(query, params).fetchone()
    return result["meta_value"]


def main() -> None:
    """
    Main function to run the script.
    """
    args = parse_arguments()
    db_url = args.database
    ref_db = args.ref_db

    rr_dbc = DBConnection(db_url)

    ref_gdb, ref_species, _, query_species, _ = get_closest_ref(rr_dbc, ref_db)

    nr_homologs, nr_genes = query_rr_database(rr_dbc, ref_gdb, ref_db)
    perc_homologs = round((nr_homologs * 100 / nr_genes), 1)
    json_data: Dict[str, Any] = {
        f"homologs_against_{ref_species}": perc_homologs,
    }
    if args.detailed:
        json_data = {
            "production_name": query_species,
            "homology_coverage": perc_homologs,
            "reference_species": ref_species,
        }

    if args.refcoll:
        json_data["refcoll_info"] = {k: get_meta_value(rr_dbc, k) for k in ["refdb_version", "ref_coll"]}

    with open(args.output, "w", encoding="utf-8") as outfile:
        json.dump(json_data, outfile)


if __name__ == "__main__":
    main()
