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
"""Link each pairwise Cactus MLSS to a suitable reference Cactus MLSS."""

import argparse
from collections import defaultdict
from itertools import combinations
import re
import sys
from typing import DefaultDict, Dict, FrozenSet, List, Sequence
import warnings

import sqlalchemy
from sqlalchemy import create_engine, text


def _calculate_pairwise_genomic_coverage(
    connection: sqlalchemy.engine.Connection, msa_mlss_ids: Sequence[int], mlss_to_gdbs: Dict[int, FrozenSet]
) -> Dict:
    pw_cov_query = text(
        """\
            SELECT
                genome_db_id,
                tag,
                value
            FROM
                species_tree_node
            JOIN
                species_tree_node_tag USING(node_id)
            JOIN
                species_tree_root USING(root_id)
            WHERE
                method_link_species_set_id = :mlss_id
            AND
                (tag = 'total_genome_length' OR tag REGEXP '^genome_coverage_[0-9]+$')
        """
    )

    pw_cov_tag_re = re.compile("genome_coverage_(?P<gdb_id>[0-9]+)")

    pairwise_coverage: Dict = {}

    for mlss_id in msa_mlss_ids:
        pairwise_coverage[mlss_id] = {}
        gdb_to_length = {}
        genome_db_to_pairwise_coverage: DefaultDict = defaultdict(lambda: defaultdict(int))
        for gdb1_id, tag, value in connection.execute(pw_cov_query, {"mlss_id": mlss_id}):
            if match := pw_cov_tag_re.fullmatch(tag):
                gdb2_id = int(match["gdb_id"])
                genome_db_to_pairwise_coverage[gdb1_id][gdb2_id] = float(value)
            else:  # tag == 'total_genome_length'
                gdb_to_length[gdb1_id] = float(value)
        gdb_to_pw_cov = {k: dict(x) for k, x in genome_db_to_pairwise_coverage.items()}
        for gdb1_id, gdb2_id in combinations(mlss_to_gdbs[mlss_id], 2):
            try:
                pw_cov_on_gdb1 = gdb_to_pw_cov[gdb1_id][gdb2_id]
                pw_cov_on_gdb2 = gdb_to_pw_cov[gdb2_id][gdb1_id]
                gdb1_genome_length = gdb_to_length[gdb1_id]
                gdb2_genome_length = gdb_to_length[gdb2_id]
            except KeyError:  # any key error here would prevent calculation of pairwise coverage
                continue

            gdb_pair = frozenset([gdb1_id, gdb2_id])
            pairwise_coverage[mlss_id][gdb_pair] = (pw_cov_on_gdb1 + pw_cov_on_gdb2) / (
                gdb1_genome_length + gdb2_genome_length
            )

    return pairwise_coverage


def _fetch_all_current_mlsses_by_method_link_type(
    connection: sqlalchemy.engine.Connection, method_link_type: str, current_release: int
) -> List[int]:
    query = text(
        """\
            SELECT
                method_link_species_set_id
            FROM
                method_link_species_set
            JOIN
                method_link USING(method_link_id)
            WHERE
                method_link.type = :method_link_type
            AND
                (first_release IS NOT NULL AND first_release <= :release)
            AND
                (last_release IS NULL OR last_release >= :release)
            ORDER BY
                method_link_species_set_id
        """
    )

    mlss_ids = []
    params = {"method_link_type": method_link_type, "release": current_release}
    for (mlss_id,) in connection.execute(query, params):
        mlss_ids.append(mlss_id)

    return mlss_ids


def _fetch_mlss_gdb_map(connection: sqlalchemy.engine.Connection, mlss_ids: Sequence[int]) -> Dict:
    query = text(
        """\
            SELECT
                genome_db_id
            FROM
                method_link_species_set
            JOIN
                species_set USING(species_set_id)
            WHERE
                method_link_species_set_id = :mlss_id
        """
    )

    mlss_gdb_map = {}
    for mlss_id in mlss_ids:
        gdb_set = set()
        for (genome_db_id,) in connection.execute(query, {"mlss_id": mlss_id}):
            gdb_set.add(genome_db_id)
        mlss_gdb_map[mlss_id] = frozenset(gdb_set)

    return mlss_gdb_map


def _get_original_url(connection: sqlalchemy.engine.Connection, mlss_id: int) -> str:
    mlss_url_query = text(
        """\
            SELECT
                url
            FROM
                method_link_species_set
            JOIN
                method_link USING(method_link_id)
            WHERE
                method_link_species_set_id = :mlss_id
        """
    )

    return connection.execute(mlss_url_query, {"mlss_id": mlss_id}).scalar()


def _link_cactus_pairwise_mlsses(
    connection: sqlalchemy.engine.Connection, reference_mlsses: Dict, mlss_to_url: Dict, dry_run: bool = False
) -> None:
    tag_delete_statement = text(
        """\
            DELETE FROM
                method_link_species_set_tag
            WHERE
                method_link_species_set_id = :pw_mlss_id
            AND
                tag = 'alt_hal_mlss'
        """
    )

    tag_insert_statement = text(
        """\
            INSERT INTO
                method_link_species_set_tag (method_link_species_set_id, tag, value)
            VALUES
                (:pw_mlss_id, 'alt_hal_mlss', :ref_mlss_id)
        """
    )

    url_update_statement = text(
        """\
            UPDATE
                method_link_species_set
            SET
                url = :mlss_url
            WHERE
                method_link_species_set_id = :mlss_id;
        """
    )

    num_singletons = 0
    action = "Would link" if dry_run else "Linking"
    for pw_mlss_id, ref_mlss_info in reference_mlsses.items():
        ref_mlss_id = ref_mlss_info["ref_mlss_id"]
        reason = ref_mlss_info["reason"]

        if reason == "a single candidate":
            num_singletons += 1
        else:
            print(
                f"{action} pairwise Cactus MLSS {pw_mlss_id} to reference MLSS {ref_mlss_id}"
                f" on the basis of {reason} ..."
            )

        if dry_run:
            continue

        connection.execute(
            tag_delete_statement,
            {"pw_mlss_id": pw_mlss_id},
        )
        connection.execute(
            tag_insert_statement,
            {"pw_mlss_id": pw_mlss_id, "ref_mlss_id": ref_mlss_id},
        )
        connection.execute(
            url_update_statement,
            {"mlss_id": pw_mlss_id, "mlss_url": mlss_to_url[ref_mlss_id]},
        )

    if num_singletons > 0:
        quantifier = "all" if num_singletons == len(reference_mlsses) else "remaining"
        print(
            f"{action} {quantifier} {num_singletons} pairwise Cactus MLSSes"
            f" to their single available reference MLSS ..."
        )


def _select_reference_mlsses(
    pairwise_mlss_ids: Sequence[int],
    msa_mlss_ids: Sequence[int],
    mlss_to_gdbs: Dict,
    pairwise_coverage: Dict,
    on_missing_ref_mlss: str = "raise",
) -> Dict:
    reference_mlsses = {}
    for pw_mlss_id in pairwise_mlss_ids:
        cand_ref_mlss_ids = [
            msa_mlss_id
            for msa_mlss_id in msa_mlss_ids
            if mlss_to_gdbs[pw_mlss_id] <= mlss_to_gdbs[msa_mlss_id]
        ]

        if len(cand_ref_mlss_ids) == 0:
            msg = f"no candidate reference MLSS found for pairwise Cactus MLSS {pw_mlss_id}"
            if on_missing_ref_mlss == "warn":
                warnings.warn(msg)
                continue
            if on_missing_ref_mlss == "raise":
                raise RuntimeError(msg)
            raise RuntimeError(f"'on_missing_ref_mlss' has unsupported value : {on_missing_ref_mlss}")

        if len(cand_ref_mlss_ids) == 1:
            reference_mlsses[pw_mlss_id] = {
                "ref_mlss_id": cand_ref_mlss_ids[0],
                "reason": "a single candidate",
            }
            continue

        gdb_pair = mlss_to_gdbs[pw_mlss_id]
        if all(
            mlss_id in pairwise_coverage and gdb_pair in pairwise_coverage[mlss_id]
            for mlss_id in cand_ref_mlss_ids
        ):
            max_pw_cov = max(pairwise_coverage[mlss_id][gdb_pair] for mlss_id in cand_ref_mlss_ids)
            cand_ref_mlss_ids = [
                mlss_id for mlss_id in cand_ref_mlss_ids if pairwise_coverage[mlss_id][gdb_pair] == max_pw_cov
            ]
            if len(cand_ref_mlss_ids) == 1:
                reference_mlsses[pw_mlss_id] = {
                    "ref_mlss_id": cand_ref_mlss_ids[0],
                    "reason": "pairwise coverage",
                }
                continue

        min_mlss_size = min(len(mlss_to_gdbs[mlss_id]) for mlss_id in cand_ref_mlss_ids)
        cand_ref_mlss_ids = [
            mlss_id for mlss_id in cand_ref_mlss_ids if len(mlss_to_gdbs[mlss_id]) == min_mlss_size
        ]

        if len(cand_ref_mlss_ids) == 1:
            reference_mlsses[pw_mlss_id] = {
                "ref_mlss_id": cand_ref_mlss_ids[0],
                "reason": "MLSS size",
            }
        else:
            reference_mlsses[pw_mlss_id] = {
                "ref_mlss_id": max(cand_ref_mlss_ids),
                "reason": "MLSS ID",
            }

    return reference_mlsses


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--url",
        help="URL of Compara database in which pairwise Cactus MLSSes are to be linked.",
    )
    parser.add_argument(
        "--release",
        type=int,
        required=True,
        help="Current Ensembl release.",
    )
    parser.add_argument(
        "--on-missing-ref-mlss",
        default="raise",
        choices=["raise", "warn"],
        help="What to do if a pairwise Cactus MLSS has no suitable reference MLSS.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print how pairwise Cactus MLSSes would be linked, but do not update the database.",
    )

    args = parser.parse_args()

    engine = create_engine(args.url)

    with engine.connect() as conn:
        cactus_pw_mlss_ids = _fetch_all_current_mlsses_by_method_link_type(
            conn, "CACTUS_HAL_PW", args.release
        )

        if not cactus_pw_mlss_ids:
            print("No pairwise Cactus MLSSes found; exiting")
            sys.exit(0)

        cactus_msa_mlss_ids = _fetch_all_current_mlsses_by_method_link_type(conn, "CACTUS_HAL", args.release)

        cactus_msa_mlss_to_url = {
            mlss_id: _get_original_url(conn, mlss_id) for mlss_id in cactus_msa_mlss_ids
        }

        mlss_to_gdb_set = _fetch_mlss_gdb_map(conn, cactus_msa_mlss_ids + cactus_pw_mlss_ids)

        mlss_pw_cov_info = _calculate_pairwise_genomic_coverage(conn, cactus_msa_mlss_ids, mlss_to_gdb_set)

        pw_to_ref_mlss_info = _select_reference_mlsses(
            cactus_pw_mlss_ids,
            cactus_msa_mlss_ids,
            mlss_to_gdb_set,
            mlss_pw_cov_info,
            on_missing_ref_mlss=args.on_missing_ref_mlss,
        )

    with engine.begin() as conn:
        _link_cactus_pairwise_mlsses(conn, pw_to_ref_mlss_info, cactus_msa_mlss_to_url, dry_run=args.dry_run)
