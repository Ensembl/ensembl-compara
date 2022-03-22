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

    $ python appropriate_ref_collection.py --taxon_name canis_lupis_familiaris \
        --url mysql://ensro@mysql-ens-mirror-1:4240/ncbi_taxonomy_106 \
        --ref_base_dir /hps/nobackup/flicek/ensembl/compara/shared/reference_sets \

"""

import os
from pathlib import Path
import sys

from argparse import ArgumentParser

from sqlalchemy.orm import Session
from sqlalchemy.orm.exc import NoResultFound

from ensembl.database import DBConnection
from ensembl.compara.utils.taxonomy import (
    collect_taxonomys_from_path,
    match_taxon_to_reference,
)


def get_collection_path(session: Session, taxon: str, ref_base_dir: Path) -> Path:
    """Returns an appropriate reference collection directory for query ``taxon``

    Args:
        session: sqlalchemy.orm.Session object holding database connection
        taxon: Scientific taxon name as in ncbi_taxonomy
        ref_base_dir: collections directory containing directories
            named by taxonomic classification
    """
    refs_dir = collect_taxonomys_from_path(session, ref_base_dir)
    ref_taxon = match_taxon_to_reference(session, taxon, refs_dir)
    return Path(os.path.join(ref_base_dir, ref_taxon))

if __name__ == "__main__":

    parser = ArgumentParser(
        description='Selects appropriate reference collection directory for a given `taxon_name`.'
    )
    parser.add_argument(
        "--taxon_name", help="Species of interest species_genus<_gca>", type=str
    )
    parser.add_argument(
        "--ref_base_dir", help="Path to parent directory of comparator sets", type=str
    )
    parser.add_argument(
        "--url", help="URL of ncbi_taxonomy database", type=str
    )
    args = parser.parse_args(sys.argv[1:])

    try:
        dbc = DBConnection(args.url)
        with dbc.session_scope() as sesh:
            collection_path = get_collection_path(
                sesh, args.taxon_name, args.ref_base_dir
            )
            print(collection_path)
    except (TypeError, AttributeError, NoResultFound):
        print("A valid --taxon_name, --ref_base_dir and --url are required")
