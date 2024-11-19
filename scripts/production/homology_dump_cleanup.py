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
""" Clean-up Homology dumps """

import argparse
import logging
import os
import shutil
import sys
import textwrap
from typing import Any, List, Optional, Tuple

from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

# Type aliases for readability
SQLResult = List[Tuple[Any, ...]]
UniqueCollections = List[str]


def mysql_query(
    query: str,
    db_url: str,
    params: Optional[Any] = None,
) -> SQLResult:
    """
    Execute a MySQL query and return the result.

    This function takes a SQL query as a string and a database URL,
    executes the query, and returns the result as SQLResult.
    It optionally accepts parameters to bind to the query.

    Parameters:
        query : The SQL query to be executed.
        db_url : The database URL for connecting to the MySQL database.
        params : Optional parameters to bind to the SQL query.
                    If not provided, an empty dictionary is used.

    Returns:
        A list of tuples containing the rows returned by the query.

    Raises:
        If an error occurs during the execution of the query.
    """

    if not params:
        params = {}

    try:
        engine = create_engine(db_url)
        with engine.connect() as conn:
            info = conn.execute(text(query), params)
            return [tuple(x) for x in info]
    except SQLAlchemyError:
        logging.exception("MySQL Error")
        raise


def get_collections(db_url: str, current_release: int) -> UniqueCollections:
    """
    Retrieves unique collection names from a MySQL database before a specified Ensembl release.

    This function connects to a MySQL database using the provided database URL, executes a query
    to retrieve distinct collection names. It processes these names to remove the 'collection-'
    prefix if present and returns a sorted list of unique names.

    Args:
        db_url: The database URL in the format 'mysql://user:password@host:port/database'.
        current_release: The current Ensembl release.

    Returns:
        A sorted list of unique collection names.
    """
    collections_query = (
        "SELECT DISTINCT ssh.name "
        "FROM method_link_species_set mlss "
        "JOIN method_link ml USING(method_link_id) "
        "JOIN species_set_header ssh USING(species_set_id) "
        "WHERE ml.type IN ('PROTEIN_TREES', 'NC_TREES') "
        "AND mlss.first_release IS NOT NULL "
        "AND mlss.first_release <= :current_release;"
    )

    params = {"current_release": current_release}
    sql = mysql_query(collections_query, db_url, params)
    result = sorted(set(collection.removeprefix("collection-") for collection, in sql))
    return result


def get_division_info(db_url: str) -> tuple[str, int]:
    """
    Retrieves division information from a MySQL database.

    This function connects to a MySQL database using the provided database URL and executes
    a query to retrieve values for the 'division' and 'schema_version' keys from the 'meta' table.

    Args:
        db_url: The database URL in the format 'mysql://user:password@host:port/database'.

    Returns:
        Tuple containing the division and release of the MySQL database.
    """
    div_rel_query = (
        "SELECT meta_key, meta_value FROM meta WHERE meta_key IN ('division', 'schema_version');"
    )

    metadata: dict[str, int] = dict(mysql_query(div_rel_query, db_url))
    return metadata["division"], int(metadata["schema_version"])


def remove_directory(dir_path: str, dry_run: bool) -> None:
    """
    Removes a directory if dry_run is False.

    This function attempts to remove the specified directory. If `dry_run` is True, it logs the
    action that would have been taken without actually deleting the directory. If `dry_run` is
    False, it deletes the directory and logs the deletion. If an error occurs during the deletion
    process, it logs the error and raises the exception.

    Args:
        dir_path: The path to the directory to be removed.
        dry_run: If True, the directory will not be removed, and the action will only be logged.
    """
    if not dry_run:
        try:
            shutil.rmtree(dir_path)
            logging.info("Removed directory: %s", dir_path)
        except Exception:
            logging.exception("Error removing directory: %s", dir_path)
            raise
    else:
        logging.info("Dry run mode: Would have removed directory: %s", dir_path)


def process_collection_directory(
    collection_path: str, num_releases_to_keep: int, dry_run: bool
) -> bool:
    """
    Processes a collection directory and removes subdirectories.

    This function scans the specified collection directory for subdirectories with numeric names.
    If the numeric value of the subdirectory name is not in the set of releases to keep (as determined
    by the num_releases_to_keep parameter), the subdirectory is removed, unless dry_run is True.
    In dry_run mode, the function logs the actions it would take without
    actually performing any deletions.

    Args:
        collection_path: Path to the collection directory to process.
        num_releases_to_keep: Ensembl release cutoff indicating number of releases to keep;
            subdirectories with numeric names less than this value will be considered for removal.
        dry_run: If True, performs a dry run without actually deleting directories.

    Returns:
        True if any directories were removed; False otherwise.
    """
    dirs_removed = False
    rel_to_cleanup_path = {}
    with os.scandir(collection_path) as coll_path:
        for k in coll_path:
            try:
                release = int(k.name)
            except ValueError:
                continue
            rel_to_cleanup_path[release] = k.path

    releases = sorted(rel_to_cleanup_path.keys(), reverse=True)
    releases_to_keep = releases[:num_releases_to_keep]

    for release_to_keep in releases_to_keep:
        del rel_to_cleanup_path[release_to_keep]

    for cleanup_path in rel_to_cleanup_path.values():
        if os.path.isdir(cleanup_path):
            remove_directory(cleanup_path, dry_run)
            dirs_removed = True

    if not dirs_removed and not dry_run:
        logging.info(
            "No directories found for removal in %s collection.", collection_path
        )

    return dirs_removed


def iterate_collection_dirs(
    div_path: str, collections: UniqueCollections, num_releases_to_keep: int, dry_run: bool
) -> None:
    """
    Iterates over collection directories within a division path and processes each collection.

    This function scans the specified division directory for subdirectories that match the names
    in the provided collections. For each matching collection directory, it calls
    `process_collection_directory` to remove subdirectories according to specified parameters, unless
    dry_run is True. In dry_run mode, the function logs the actions it would take without
    actually performing any deletions.

    Args:
        div_path: Path to the division directory containing collection directories.
        collections: A list of collection names to look for within the division directory.
        num_releases_to_keep: Ensembl release cutoff indicating number of releases to keep;
            subdirectories within each collection directory with numeric names less than
            this value will be considered for removal.
        dry_run: If True, performs a dry run without actually deleting directories.
    """
    with os.scandir(div_path) as div_dir:
        for j in div_dir:
            if j.is_dir() and j.name in collections:
                collection_path = os.path.join(div_path, j.name)
                process_collection_directory(collection_path, num_releases_to_keep, dry_run)


def cleanup_homology_dumps(
    homology_dumps_dir: str,
    num_releases_to_keep: int,
    dry_run: bool,
    collections: UniqueCollections,
    division: str,
    log_file: Optional[str] = None,
) -> None:
    """
    Cleans up homology dump directories based on specified criteria.

    This function coordinates the cleanup process for homology dump directories.
    It iterates through collection directories within the specified `div_path`,
    processing each collection using `iterate_collection_dirs`. For each matching
    collection directory, it calls `process_collection_directory` to remove
    subdirectories representing a release prior to the releases being kept, unless dry_run is True.
    In dry run mode, the function logs the actions it would take without
    performing any deletions.

    Args:
        homology_dumps_dir : Path to the homology dumps directory.
        num_releases_to_keep : Ensembl release cutoff indicating number of releases to keep;
        subdirectories within each collection directory with numeric names
        less than this value will be considered for removal.
        dry_run : If True, performs a dry run without actually deleting directories.
        log_file : Path to the log file.
        collections : A list of collection names to look for within each division directory.
                        Defaults to an empty list.
        division : Division name.
    """
    logging_kwargs: dict = {
        "format": "%(asctime)s - %(message)s",
        "level": logging.INFO,
    }
    if log_file:
        logging_kwargs["filename"] = log_file
    else:
        logging_kwargs["stream"] = sys.stdout
    logging.basicConfig(**logging_kwargs)


    div_path = os.path.join(homology_dumps_dir, division)
    iterate_collection_dirs(div_path, collections, num_releases_to_keep, dry_run)

    if not dry_run:
        logging.info("Cleanup process completed.")
    else:
        logging.info("Dry run mode: Cleanup process completed.")


def parse_args() -> argparse.Namespace:
    """
    Returns command-line arguments for the homology dumps cleanup script.
    """
    description = textwrap.dedent(
        """\
    Homology dumps cleanup script
    Example command to run this script from command line:
    >>> ./homology_dump_cleanup.py
    --homology_dumps_dir /hps/nobackup/flicek/ensembl/compara/sbhurji/scripts/homology_dumps
    --master_db_url mysql://ensro@mysql-ens-compara-prod-5:4615/ensembl_compara_master_plants
    --num_releases_to_keep 1 --dry_run
    --log /hps/nobackup/flicek/ensembl/compara/sbhurji/scripts/clean.log
    """
    )
    parser = argparse.ArgumentParser(
        description=description, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--homology_dumps_dir",
        required=True,
        help="Root directory of the homology dumps.",
    )
    parser.add_argument(
        "--master_db_url", type=str, required=True, help="URL of the master database."
    )
    parser.add_argument(
        "--num_releases_to_keep",
        type=int,
        required=True,
        help=(
            "Keep homology dumps only for this number of releases,"
            " and delete all homology dumps from releases prior to that."
        ),
    )
    parser.add_argument(
        "--dry_run",
        action="store_true",
        help="Perform a dry run without deleting files.",
    )
    parser.add_argument(
        "--log", type=str, help="Optional log file to record deleted files."
    )

    return parser.parse_args()


def main() -> None:
    """
    This is the main function to parse arguments, retrieve database collections, 
    obtain division information, validate input, and initiate the 
    cleanup of homology dumps.

    Raises:
        ValueError: If `num_releases_to_keep` is not greater than zero.
    """
    args = parse_args()
    division, release = get_division_info(args.master_db_url)
    collections = get_collections(args.master_db_url, release)

    if args.num_releases_to_keep < 1:
        raise ValueError("num_releases_to_keep must be greater than zero")

    cleanup_homology_dumps(
        args.homology_dumps_dir,
        args.num_releases_to_keep,
        args.dry_run,
        collections,
        division,
        args.log,
    )


if __name__ == "__main__":
    main()
