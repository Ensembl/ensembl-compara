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
"""Classifies the appropriate set of comparators for a taxon by taxonomic-directory

Example::

    $ python appropriate_ref_collection_fasta.py --taxon_name canis_lupis_familiaris \
        --genome_fasta ${ENSEMBLFTP}/Canis_lupus_familiaris/Canis_lupus_familiaris.fasta \
        --url mysql://ensro@mysql-ens-sta-1:4519/ncbi_taxonomy_106 \
        --comparators_dir /hps/nobackup/flicek/ensembl/compara/shared/references_symlink_fasta \
        --dest_dir '45.88.81.155:/bucket3'

"""

import os
from os.path import basename
from pathlib import Path
from shutil import copytree, copyfile
import sys

from argparse import ArgumentParser

from sqlalchemy.orm import Session

from ensembl.database import DBConnection
from ensembl.compara.utils.taxonomy import (
    collect_taxonomys_from_path,
    match_taxon_to_reference,
)


def get_collection_path(session: Session, taxon: str, ref_dir: Path) -> Path:
    """Returns an appropriate reference collection directory for query ``taxon``

    Args:
        taxon: Scientific taxon name as in ncbi_taxonomy
        dir: collections directory containing directories
            named by taxonomic classification
    """
    refs_dir = collect_taxonomys_from_path(session, ref_dir)
    ref_taxon = match_taxon_to_reference(session, taxon, refs_dir)
    return Path(os.path.join(ref_dir, ref_taxon))


def duplicate_collection_path(taxon: str, src: Path, dest: Path) -> Path:
    """Copies given directory to given location and renames for query ``taxon``

    Args:
        taxon: Scientific taxon name as in ncbi_taxonomy
        src: Collections directory named by taxonomic classification
        dest: Path of new directory parent
    """
    destination = str(dest) + '/' + str(taxon)
    try:
        new_collection = copytree(src, destination)
        return Path(new_collection)
    except FileExistsError:
        return Path(destination)
    return None


if __name__ == "__main__":

    parser = ArgumentParser(
        description='Copies a reference collection directory to include a given `taxon_name` fasta.'
    )
    parser.add_argument(
        "--taxon_name", help="Species of interest species_genus<_gca>", type=str
    )
    parser.add_argument(
        "--genome_fasta", help="Path to species fasta file", type=str
    )
    parser.add_argument(
        "--dest_dir", help="Destination of new directory", type=str
    )
    parser.add_argument(
        "--comparators_dir", help="Path to parent directory of comparator sets", type=str
    )
    parser.add_argument(
        "--url", help="URL of ncbi_taxonomy database", type=str
    )
    args = parser.parse_args(sys.argv[1:])

    try:
        dbc = DBConnection(args.url)
        with dbc.session_scope() as sesh:
            collection_path = get_collection_path(
                sesh, args.taxon_name, args.comparators_dir
            )
            target_dir = duplicate_collection_path(
                args.taxon_name, Path(collection_path), Path(args.dest_dir)
            )
            filename = basename(args.genome_fasta)
            new_dest = os.path.join(target_dir, filename)
            try:
                copyfile(args.genome_fasta, new_dest)
                print(os.listdir(target_dir))
            except (FileExistsError, FileNotFoundError):
                print(f"Unable to copy {basename(args.genome_fasta)} to destination")
    except (TypeError, AttributeError):
        print(
            "A valid --taxon_name, --genome_fasta, --dest_dir, --comparators_dir and --url are required"
        )
