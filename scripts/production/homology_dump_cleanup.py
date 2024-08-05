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
    executes the query, and returns the result as a list of tuples.
    It optionally accepts parameters to bind to the query.

    Parameters:
    query (str): The SQL query to be executed.
    db_url (str): The database URL for connecting to the MySQL database.
    params (Optional[Any]): Optional parameters to bind to the SQL query.
                            If not provided, an empty dictionary is used.

    Returns:
    SQLResult: A list of tuples containing the rows returned by the query.

    Raises:
    SQLAlchemyError: If an error occurs during the execution of the query.
    """

    if not params:
        params = {}

    try:
        engine = create_engine(db_url)
        with engine.connect() as conn:
            info = conn.execute(query, **params)
            return [tuple(x) for x in info]
    except SQLAlchemyError:
        logging.exception("MySQL Error")
        raise


def get_collections(db_url: str, before_release: int) -> UniqueCollections:
    """
    Retrieves unique collection names from a MySQL database before a specified Ensembl release.

    This function connects to a MySQL database using the provided database URL, executes a query
    to retrieve distinct collection names related to 'PROTEIN_TREES' and 'NC_TREES' that were
    first released on or before the specified Ensembl release number. It then processes these
    names to remove the 'collection-' prefix if present and returns a sorted list of unique names.

    Args:
        db_url: The database URL in the format 'mysql://user:password@host:port/database'.
        before_release: The Ensembl release number to use as a cutoff for selecting collections.

    Returns:
        UniqueCollections: A sorted list of unique collection names.
    """
    collections_query = text(
        "SELECT DISTINCT ssh.name "
        "FROM method_link_species_set mlss "
        "JOIN method_link ml USING(method_link_id) "
        "JOIN species_set_header ssh USING(species_set_id) "
        "WHERE ml.type IN ('PROTEIN_TREES', 'NC_TREES') "
        "AND mlss.first_release IS NOT NULL "
        "AND mlss.first_release <= :before_release;"
    )

    params = {"before_release": before_release}
    sql = mysql_query(collections_query, db_url, params)
    result = sorted(set(collection.removeprefix("collection-") for collection, in sql))
    return result


def get_division_info(db_url: str) -> SQLResult:
    """
    Retrieves division and schema version information from a MySQL database.

    This function connects to a MySQL database using the provided database URL and executes
    a query to retrieve values for the 'division' and 'schema_version' keys from the 'meta' table.
    The retrieved values are then returned as a SQLResult.

    Args:
        db_url: The database URL in the format 'mysql://user:password@host:port/database'.

    Returns:
        SQLResult: A tuple containing tuples of the retrieved meta values.
    """
    div_rel_query = (
        "SELECT meta_value FROM meta WHERE meta_key IN ('division', 'schema_version');"
    )

    sql = mysql_query(div_rel_query, db_url)
    return sql


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

    Returns:
        None
    """
    if not dry_run:
        try:
            shutil.rmtree(dir_path)
            logging.info("Removed directory: %s", dir_path)
        except Exception as err:
            logging.error("Error removing directory: %s: %s", dir_path, err)
            raise
    else:
        logging.info("Dry run mode: Would have removed directory: %s", dir_path)


def process_collection_directory(
    collection_path: str, before_release: int, dry_run: bool
) -> bool:
    """
    Processes a collection directory and removes subdirectories older than before_release.

    This function scans the specified collection directory for subdirectories with numeric names.
    If the numeric value of the subdirectory name is less than the specified before_release value,
    the subdirectory is removed, unless dry_run is True. In dry_run mode, the function logs the
    actions it would take without actually performing any deletions.

    Args:
        collection_path: Path to the collection directory to process.
        before_release: Ensembl release cutoff; subdirectories with numeric names less than
                              this value will be considered for removal.
        dry_run: If True, performs a dry run without actually deleting directories.

    Returns:
        bool: True if any directories were removed; False otherwise.
    """
    dirs_removed = False
    with os.scandir(collection_path) as coll_path:
        for k in coll_path:
            try:
                k_release = int(k.name)
            except ValueError:
                continue
            if k.is_dir() and k_release < before_release:
                dirs_to_remove = os.path.join(collection_path, k.name)
                remove_directory(dirs_to_remove, dry_run)
                dirs_removed = True

    if not dirs_removed and not dry_run:
        logging.info(
            "No directories found for removal in %s collection.", collection_path
        )

    return dirs_removed


def iterate_collection_dirs(
    div_path: str, collections: UniqueCollections, before_release: int, dry_run: bool
) -> None:
    """
    Iterates over collection directories within a division path and processes each collection.

    This function scans the specified division directory for subdirectories that match the names
    in the provided collections. For each matching collection directory, it calls
    `process_collection_directory` to remove subdirectories older than before_release, unless
    dry_run is True. In dry_run mode, the function logs the actions it would take without
    actually performing any deletions.

    Args:
        div_path: Path to the division directory containing collection directories.
        collections: A list of collection names to look for within the division directory.
        before_release: Ensembl release cutoff; subdirectories within each collection directory with
                              numeric names less than this value will be considered for removal.
        dry_run: If True, performs a dry run without actually deleting directories.

    Returns:
        None
    """
    with os.scandir(div_path) as div_dir:
        for j in div_dir:
            if j.is_dir() and j.name in collections:
                collection_path = os.path.join(div_path, j.name)
                process_collection_directory(collection_path, before_release, dry_run)


def cleanup_homology_dumps(
    homology_dumps_dir: str,
    before_release: int,
    dry_run: bool,
    collections: UniqueCollections,
    div_info: SQLResult,
    log_file: Optional[str] = None,
) -> None:
    """
    Cleans up outdated homology dump directories based on specified criteria.

    This function coordinates the cleanup process for homology dump directories.
    It iterates through division directories within the specified `homology_dumps_dir`,
    processing each division using `iterate_division_dirs`.
    For each division, it checks for collections listed in `collections`
    and uses division information from `div_info`to determine which directories to remove.
    Directories with numeric names less than `before_release` are considered
    for removal unless `dry_run` is True.
    In dry run mode, the function logs the actions it would take without
    performing any deletions.

    Args:
        homology_dumps_dir : Path to the homology dumps directory.
        before_release : Ensembl release cutoff;
        subdirectories within each collection directory with numeric names
        less than this value will be considered for removal.
        dry_run : If True, performs a dry run without actually deleting directories.
        log_file : Path to the log file.
        collections : A list of collection names to look for within each division directory.
                                                   Defaults to an empty list.
        div_info : A list of tuples containing division information,
        first tuple has the division name and the second tuple has the schema version

    Returns:
        None
    """
    if log_file:
        logging.basicConfig(
            filename=log_file, level=logging.INFO, format="%(asctime)s - %(message)s"
        )

    # div, version = div_info
    div_path = os.path.join(homology_dumps_dir, div_info[0][0])
    iterate_collection_dirs(div_path, collections, before_release, dry_run)

    if not dry_run:
        logging.info("Cleanup process completed.")
    else:
        logging.info("Dry run mode: Cleanup process completed.")


def parse_args():
    """
    Parse command-line arguments for the homology dumps cleanup script.

    Returns:
    - argparse.Namespace: An object containing parsed command-line arguments.

    This function uses argparse to define and parse command-line
    arguments for the homology dumps cleanup script. It expects the following arguments:

    --homology_dumps_dir: Required. Root directory of the homology dumps.
    --master_db_url: Required. URL of the master database.
    --before_release: Required. Ensembl release cutoff for cleanup (non-inclusive).
    --dry_run: Optional. If present, performs a dry run without deleting files.
    --log: Optional. Path to an optional log file to record deleted files.
    """
    parser = argparse.ArgumentParser(description="Homology dumps cleanup script")
    parser.add_argument(
        "--homology_dumps_dir",
        required=True,
        help="Root directory of the homology dumps.",
    )
    parser.add_argument(
        "--master_db_url", type=str, required=True, help="URL of the master database."
    )
    parser.add_argument(
        "--before_release",
        type=int,
        required=True,
        help="Ensembl release cutoff for cleanup (non-inclusive).",
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
    Entry point for the homology dumps cleanup script.

    This function performs the following tasks:
    1. Parses command-line arguments to get the homology dumps directory, master database URL,
       release cutoff, dry run option, and log file path.
    2. Configures logging based on the provided log file path, if any.
    3. Retrieves collections and division information from the master database using the provided URL.
    4. Calls the cleanup_homology_dumps function to perform the cleanup based on the parsed arguments.

    Command-line Arguments:
        --homology_dumps_dir (str): The root directory of the homology dumps. Required.
        --master_db_url (str): The URL of the master database. Required.
        --before_release (int): The Ensembl release cutoff for cleanup (non-inclusive). Required.
        --dry_run: Perform a dry run without deleting files. Optional.
        --log (str): Optional log file to record deleted files.

    Returns:
        None

    Example command to run this script from command line:
    >>> ./homology_dump_cleanup.py
    --homology_dumps_dir /hps/nobackup/flicek/ensembl/compara/sbhurji/scripts/homology_dumps
    --master_db_url mysql://ensro@mysql-ens-compara-prod-5:4615/ensembl_compara_master_plants
    --before_release 110 --dry_run
    --log /hps/nobackup/flicek/ensembl/compara/sbhurji/scripts/clean.log
    """
    args = parse_args()
    collections = get_collections(args.master_db_url, args.before_release)
    div_info = get_division_info(args.master_db_url)

    if args.before_release > int(div_info[1][0]):
        raise ValueError(
            f"The value {args.before_release} is greater than the allowed before_release "
            + f"limit of {div_info[1][0]}."
        )

    cleanup_homology_dumps(
        args.homology_dumps_dir,
        args.before_release,
        args.dry_run,
        collections,
        div_info,
        args.log,
    )


if __name__ == "__main__":
    main()
