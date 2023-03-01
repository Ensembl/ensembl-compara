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

"""Rapid release (RR) compara compute version and reference update reporting script

Example::

    $ python scripts/production/query_to_reference_update.py \
    --host mysql-ens-sta-x \
    --port xxxx \
    --ro_user ensro \
    --url mysql://ensro@mysql-ens-sta-x:xxxx/ensembl_compara_references \
    --release 107 \
    --compara_db_pattern canis

"""

from argparse import ArgumentParser
import os
import re
from typing import Any, Dict, List
import warnings
import json

from sqlalchemy import create_engine
from sqlalchemy.engine.url import make_url
from sqlalchemy.orm.exc import NoResultFound

from ensembl.database import DBConnection
from ensembl.compara.utils.taxonomy import fetch_scientific_name, match_taxon_to_reference


def collect_rr_dbs(rr_server: str, db_pattern: str = "") -> list:
    """Returns a list of database urls for Compara RR databases

    Args:
        rr_server: MySQL server for Rapid Release databases mysql://USER@HOST:PORT
        db_pattern: database search pattern to filter rr dbs (optional)

    Raises:
        sqlalchemy.orm.exc.NoResultFound: if no relevant dbs on server
    """
    eng = create_engine(rr_server)
    con = " WHERE `database` LIKE '%%_compara_%%' AND `database` NOT LIKE 'ensembl_%%'"
    if db_pattern:
        con += f" AND `database` LIKE '%%{db_pattern}%%'"
    q = eng.execute("SHOW DATABASES" + con)
    result = q.fetchall()
    if not result:
        raise NoResultFound()
    rr_compara_dbs = [(rr_server + "/" + r) for r, in result]
    return rr_compara_dbs


def initial_release(url: str) -> int:
    """Returns the initial release version number for a Compara RR query analysis

    Args:
        url: the url of the Compara RR database

    Raises:
        sqlalchemy.orm.exc.NoResultFound: if relevant patch row is not present
    """
    eng = create_engine(url)
    q = eng.execute(
        "SELECT meta_value FROM meta WHERE meta_key = 'patch' ORDER BY meta_id ASC LIMIT 1"
    )
    result = q.fetchall()
    if not result:
        raise NoResultFound()
    release = str(result[0]).split("_", 3)[2]
    return int(release)


def fetch_all_collections(dbc: DBConnection) -> List[Dict[Any, Any]]:
    """Returns a tuple of all collections retired and current

    Args:
        dbc: DBConnection object to database

    Raises:
        sqlalchemy.orm.exc.NoResultFound: if no collections found
    """
    q = dbc.execute(
        "SELECT species_set_id, name, first_release, last_release FROM species_set_header"
    )
    result = q.fetchall()
    if not result:
        raise NoResultFound()
    #pylint: disable=R1721
    return [{k: v for k, v in r._mapping.items()} for r in result if r is not None] # pylint: disable=W0212


def match_query_to_collection(release: int, all_collections: tuple) -> Dict[Any, Dict[str, Any]]:
    """Returns list of species_set_ids for collections available at initial compute

    Args:
        release: initial schema release of compara database
        all_collections: object of collection species_set_header rows
    """
    relevant_refs = {
        x["name"]: {
            "species_set_id": x["species_set_id"],
            "first_release": x["first_release"],
            "last_release": x["last_release"],
        }
        for x in all_collections
        if (
            x["first_release"] <= release and
            (x["last_release"] is None or x["last_release"] >= release)
        )
    }
    return relevant_refs


def fetch_current_collections(dbc: DBConnection) -> List[Dict[Any, Any]]:
    """Returns a list of all current collections

    Args:
        dbc: DBConnection object to database

    Raises:
        sqlalchemy.orm.exc.NoResultFound: if no collections found
    """
    constraint = " WHERE first_release IS NOT NULL AND last_release IS NULL"
    sql = (
        "SELECT species_set_id, name, first_release FROM species_set_header" +
        constraint
    )
    q = dbc.execute(sql)
    result = q.fetchall()
    if not result:
        raise NoResultFound()
    #pylint: disable=R1721
    return [{k: v for k, v in r._mapping.items()} for r in result if r is not None] # pylint: disable=W0212


def flag_for_update(
    q_to_c_map: dict, curr_collections: tuple, dbc: DBConnection
) -> list:
    """Returns species in need of update

    Args:
        q_to_c_map: Map of query compara databases to computed collection data
        curr_collections: Tuple of current reference collection objects
    """
    to_update = []
    curr_ss_names = [x["name"] for x in curr_collections]

    rr_compara_dbname_regex = re.compile("(?P<prod_name>[a-z0-9_]+)_compara_[0-9]+.*")
    gca_suffix_regex = re.compile("_gca_?[0-9]+(?:v[0-9]+(?:[a-z0-9_]+)?)?$")
    with dbc.session_scope() as sesh:

        for query, collection_info in q_to_c_map.items():
            url = make_url(query)
            dbname = url.database
            comparator_taxonomy = ""

            match = rr_compara_dbname_regex.fullmatch(dbname)
            try:
                genome = match["prod_name"]
            except TypeError as exc:
                raise ValueError(f"failed to extract genome name from dbname {dbname}") from exc

            query_taxon_id = get_taxon_id_from_rapid_compara_db(query)
            try:
                taxon = fetch_scientific_name(sesh, query_taxon_id)
            except NoResultFound:
                taxon = gca_suffix_regex.sub("", genome)

            potential_ss_ids = [
                collection_info[x]["species_set_id"] for x in collection_info
            ]
            if not potential_ss_ids:
                to_update.append(genome)
            else:
                try:
                    comparator_taxonomy = match_taxon_to_reference(
                        sesh, taxon, list(set(curr_ss_names))
                    )
                except NoResultFound:
                    core = query.replace("compara", "core") + "_1"

                    core_taxon_id = get_taxon_id_from_rapid_core_db(core)
                    try:
                        taxon = fetch_scientific_name(sesh, core_taxon_id)
                    except NoResultFound:
                        taxon = get_species_name(core)

                    try:
                        comparator_taxonomy = match_taxon_to_reference(
                            sesh, taxon, list(set(curr_ss_names))
                        )
                    except NoResultFound:
                        warnings.warn(
                            f"{taxon} is not a valid scientific species name in taxonomy"
                        )
                        continue
                    continue
            ss_ids = [
                x["species_set_id"]
                for x in curr_collections
                if comparator_taxonomy in x["name"]
            ]
            new_ss_id = ss_ids[0]
            if new_ss_id not in potential_ss_ids:
                to_update.append(genome)
    return list(set(to_update))


def get_species_name(url: str) -> str:
    """Returns taxonomic species name

    Args:
        url: url of core database
    """
    eng = create_engine(url)
    q = eng.execute(
        "SELECT meta_value FROM meta WHERE meta_key = 'species.scientific_name' LIMIT 1"
    )
    result = q.fetchone()
    if not result:
        raise NoResultFound()
    return result["meta_value"]


def get_taxon_id_from_rapid_compara_db(url: str) -> int:
    """Returns NCBI Taxonomy ID of species in Rapid Compara database

    This method expects there to be exactly one GenomeDB in
    the specified Compara database, and an exception will be
    raised if this is not the case.

    Args:
        url: url of Rapid Compara database
    """
    eng = create_engine(url)
    q = eng.execute(
        "SELECT taxon_id FROM genome_db"
    )
    result = q.one()
    return result["taxon_id"]


def get_taxon_id_from_rapid_core_db(url: str) -> int:
    """Returns NCBI Taxonomy ID of species in Rapid core database

    This method expects there to be exactly one 'species.taxonomy_id' entry
    in the meta table of the given core database, and an exception will be
    raised if this is not the case.

    Args:
        url: url of Rapid core database
    """
    eng = create_engine(url)
    q = eng.execute(
        "SELECT meta_value FROM meta WHERE meta_key = 'species.taxonomy_id'"
    )
    result = q.one()
    return result["meta_value"]


def main():
    """Main function to list queries run with initial schema version and reference_set version"""

    parser = ArgumentParser(
        description="Extracts RR species run with initial schema version and reference_set version"
    )
    parser.add_argument(
        "--host",
        default="mysql-ens-sta-5",
        help="Mysql server host name for Rapid Release databases",
        type=str,
    )
    parser.add_argument(
        "--port",
        default="4684",
        help="Mysql server port for Rapid Release databases host",
        type=str,
    )
    parser.add_argument(
        "--ro_user",
        default="ensro",
        help="Mysql read-only user for Rapid Release databases host",
        type=str,
    )
    parser.add_argument(
        "--out_dir",
        help="Optional output directory for query->comparator mappings",
        type=str,
    )
    parser.add_argument(
        "--url",
        help="URL of compara references database",
        type=str,
        required=True,
    )
    parser.add_argument(
        "--release",
        help="Current release of the references schema",
        type=int,
        required=True,
    )
    parser.add_argument(
        "--compara_db_pattern",
        help="Optional pattern to limit compara species databases checked",
        type=str,
    )
    args = parser.parse_args()

    rr_server = "mysql://" + args.ro_user + "@" + args.host + ":" + args.port
    rr_dbs = (
        collect_rr_dbs(rr_server, args.compara_db_pattern)
        if args.compara_db_pattern
        else collect_rr_dbs(rr_server)
    )
    ref_dbc = DBConnection(args.url)
    all_collections = fetch_all_collections(ref_dbc)
    curr_collections = fetch_current_collections(ref_dbc)

    release_map = {k: initial_release(k) for k in rr_dbs}

    to_update = {k: v for k, v in release_map.items() if v < args.release}

    qr_map = {
        k: match_query_to_collection(to_update[k], all_collections)
        for k in to_update
    }

    update_outfile = "required_updates.txt"
    mapped_outfile = "rr_species_to_comparators.txt"

    if args.out_dir:
        if os.path.isdir(args.out_dir):
            update_outfile = os.path.join(args.out_dir, update_outfile)
            mapped_outfile = os.path.join(args.out_dir, mapped_outfile)
        else:
            os.makedirs(args.out_dir, exist_ok=True)
            update_outfile = os.path.join(args.out_dir, update_outfile)
            mapped_outfile = os.path.join(args.out_dir, mapped_outfile)

    json_map = json.dumps(qr_map, indent=2)
    with open(mapped_outfile, "w") as f:
        print(json_map, file=f)

    list_to_update = flag_for_update(qr_map, curr_collections, ref_dbc)
    set(list_to_update)
    with open(update_outfile, "w") as f:
        print("\n".join(list_to_update), file=f)


if __name__ == "__main__":

    main()
