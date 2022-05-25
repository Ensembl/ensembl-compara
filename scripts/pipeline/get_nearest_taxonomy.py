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
"""Classifies the appropriate set of comparators for a taxon by taxonomic classification

Example::

    $ python get_nearest_taxonomy.py --taxon_name canis_lupus_familiaris \
        --url mysql://ensro@mysql-ens-mirror-1:4240/ncbi_taxonomy_106 \
        --taxon_list mammalia vertebrata sauropsida hexapoda \

"""

import sys
from typing import List

from argparse import ArgumentParser

from sqlalchemy.orm import Session
from sqlalchemy.orm.exc import NoResultFound

from ensembl.database import DBConnection
from ensembl.compara.utils.taxonomy import (
    match_taxon_to_reference,
)


def get_nearest_taxonomy(session: Session, taxon: str, ref_taxa: List[str]) -> str:
    """Returns an appropriate reference collection directory for query ``taxon``

    Args:
        session: sqlalchemy.orm.Session object holding database connection
        taxon: Scientific taxon name as in ncbi_taxonomy
        taxon_list: list of reference taxonomic classifications
    """
    ref_taxon = match_taxon_to_reference(session, taxon, ref_taxa)
    return ref_taxon


if __name__ == "__main__":

    parser = ArgumentParser(
        description="Selects appropriate reference taxonomy from `taxon_list` for a given `taxon_name`."
    )
    parser.add_argument(
        "--taxon_name",
        help="Species of interest species_genus",
        type=str
    )
    parser.add_argument(
        "--taxon_list",
        nargs="+",
        default=["mammalia", "vertebrata"],
        help="List of reference taxon classifications",
    )
    parser.add_argument(
        "--url",
        help="URL of ncbi_taxonomy database",
        type=str
    )
    args = parser.parse_args(sys.argv[1:])

    try:
        dbc = DBConnection(args.url)
        with dbc.session_scope() as sesh:
            comparator_taxonomy = get_nearest_taxonomy(
                sesh, args.taxon_name, args.taxon_list
            )
            print(comparator_taxonomy)
    except (TypeError, AttributeError, NoResultFound):
        print("A valid --taxon_name, --taxon_list and --url are required")
        sys.exit(1)
