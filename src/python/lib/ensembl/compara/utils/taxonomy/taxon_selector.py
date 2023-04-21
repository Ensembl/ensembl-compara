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
"""Collection of taxonomy methods to configure and extract taxonomy related information.

Typical usage examples::

    from ensembl.compara.utils.taxonomy import (
        collect_taxonomys_from_path,
        match_taxon_to_reference
    )

    with self.dbc.session_scope() as session:
        ref_dirs = collect_taxonomys_from_path(session, self.dir)
        ref_taxon = match_taxon_to_reference(session, taxon_name, ref_dirs)

"""

import os
from pathlib import Path
from typing import List, Optional, Union

from sqlalchemy.orm import Session
from sqlalchemy.orm.exc import NoResultFound

from ensembl.ncbi_taxonomy.api.utils import Taxonomy
from ensembl.ncbi_taxonomy.models import NCBITaxaName


def collect_taxonomys_from_path(session: Session, rootdir: Union[str, Path]) -> List[str]:
    """Returns a list of ncbi_taxa_name.names

    Args:
        session: sqlalchemy.orm.Session object holding database connection
        rootdir: Collections directory containing directories
        named by taxonomic classification
    """
    if not Path(rootdir).is_dir():
        raise FileNotFoundError
    subdir_names = [f.name for f in os.scandir(rootdir) if f.is_dir(follow_symlinks=True)]
    valid_taxons = [filter_real_taxon(session, name) for name in subdir_names]
    taxon_list = list(filter(None, valid_taxons)) # type: List[str]
    return taxon_list


def match_taxon_to_reference(session: Session, taxon_name: str, taxon_list: list) -> str:
    """Returns a taxonomic clade name within the ``taxon_list`` and ``taxon_name`` ancestry

    Args:
        session: sqlalchemy.orm.Session object holding database connection
        taxon_name: Scientific ncbi_taxa_name.name of genome in database
        taxon_list: List of clade ncbi_taxa_name.names
    """
    node = Taxonomy.fetch_taxon_by_species_name(session, taxon_name)
    ancestor_nodes = Taxonomy.fetch_ancestors(session, node.taxon_id)
    ordered_ancestors = order_ancestry(session, ancestor_nodes)
    ancestors = [ancestor["taxon_id"] for ancestor in ordered_ancestors]
    result = None
    for ancestor in ancestors:
        ancestor_name = fetch_scientific_name(session, ancestor)
        if any(str(ancestor_name).lower() == taxon.lower() for taxon in taxon_list):
            result = str(ancestor_name).lower()
    return result if result is not None else "default"


def filter_real_taxon(session: Session, taxon_name: str)-> Optional[str]:
    """Returns a taxonomic name if it exists

    Args:
        taxon_name: Scientific ncbi_taxa_name.name of genome in database
    """
    try:
        Taxonomy.fetch_taxon_by_species_name(session, taxon_name)
        return taxon_name
    except NoResultFound:
        return None


def fetch_scientific_name(session: Session, taxon_id: int) -> str:
    """Returns a taxononomic name if it exists in database

    Args:
        taxon_id: ncbi_taxa_node.taxon_id of node in database

    Raises:
        sqlalchemy.orm.exc.NoResultFound: if ``taxon_id`` does not exist
    """
    q = (
        session.query(NCBITaxaName)
        .filter(NCBITaxaName.taxon_id == taxon_id)
        .filter(NCBITaxaName.name_class == "scientific name")
        .one()
    )
    if not q:
        raise NoResultFound()
    return q.name

def order_ancestry(session: Session, ancestors: tuple) -> tuple:
    """Returns an ordered and filtered tuple of ancestor objects

    Args:
        ancestors: tuple of ancestor node objects
    """
    ancestor_nodes = list(ancestors)
    ordered_ancestors = sorted(
        ancestor_nodes,
        key=lambda x: Taxonomy.num_descendants(session, x["taxon_id"]),
        reverse=True
    )
    return tuple(ordered_ancestors)
