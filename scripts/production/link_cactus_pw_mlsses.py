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
from collections.abc import MutableMapping, Set
from itertools import combinations
import re
import sys
import warnings

from sqlalchemy import create_engine, text


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
        default="warn",
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

    cactus_pw_mlss_query = text(
        """\
            SELECT
                method_link_species_set_id
            FROM
                method_link_species_set
            JOIN
                method_link USING(method_link_id)
            WHERE
                method_link.type = 'CACTUS_HAL_PW'
            AND
                (first_release IS NOT NULL AND first_release <= :release)
            AND
                (last_release IS NULL OR last_release >= :release)
            ORDER BY
                method_link_species_set_id
        """
    )
    cactus_pw_mlss_ids = []
    with engine.connect() as conn:
        for (mlss_id,) in conn.execute(cactus_pw_mlss_query, {"release": args.release}):
            cactus_pw_mlss_ids.append(mlss_id)

    if not cactus_pw_mlss_ids:
        print("No pairwise Cactus MLSSes found; exiting")
        sys.exit(0)

    cactus_msa_mlss_query = text(
        """\
            SELECT
                method_link_species_set_id,
                url
            FROM
                method_link_species_set
            JOIN
                method_link USING(method_link_id)
            WHERE
                method_link.type = 'CACTUS_HAL'
            AND
                (first_release IS NOT NULL AND first_release <= :release)
            AND
                (last_release IS NULL OR last_release >= :release)
            ORDER BY
                method_link_species_set_id
        """
    )
    cactus_msa_mlss_to_url = {}
    with engine.connect() as conn:
        for mlss_id, mlss_url in conn.execute(cactus_msa_mlss_query, {"release": args.release}):
            cactus_msa_mlss_to_url[mlss_id] = mlss_url

    cactus_msa_mlss_ids = sorted(cactus_msa_mlss_to_url, reverse=True)

    mlss_gdb_query = text(
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
    mlss_to_size = {}
    mlss_to_gdb_set: MutableMapping[int, Set] = {}
    with engine.connect() as conn:
        for mlss_id in cactus_msa_mlss_ids + cactus_pw_mlss_ids:
            gdb_set = set()
            for (genome_db_id,) in conn.execute(mlss_gdb_query, {"mlss_id": mlss_id}):
                gdb_set.add(genome_db_id)
            mlss_to_gdb_set[mlss_id] = frozenset(gdb_set)
            mlss_to_size[mlss_id] = len(gdb_set)

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

    mlss_pw_cov_info: MutableMapping[int, MutableMapping[Set, float]] = {}
    with engine.connect() as conn:
        for mlss_id in cactus_msa_mlss_ids:
            mlss_pw_cov_info[mlss_id] = {}
            gdb_to_length = {}
            gdb_to_pw_cov: MutableMapping[int, MutableMapping[int, int]] = defaultdict(
                lambda: defaultdict(int)
            )
            for gdb1_id, tag, value in conn.execute(pw_cov_query, {"mlss_id": mlss_id}):
                if match := pw_cov_tag_re.fullmatch(tag):
                    gdb2_id = int(match["gdb_id"])
                    gdb_to_pw_cov[gdb1_id][gdb2_id] = int(value)
                else:  # tag == 'total_genome_length'
                    gdb_to_length[gdb1_id] = int(value)
            gdb_to_pw_cov = {k: dict(x) for k, x in gdb_to_pw_cov.items()}
            for gdb1_id, gdb2_id in combinations(mlss_to_gdb_set[mlss_id], 2):
                try:
                    pw_cov_on_gdb1 = gdb_to_pw_cov[gdb1_id][gdb2_id]
                    pw_cov_on_gdb2 = gdb_to_pw_cov[gdb2_id][gdb1_id]
                    gdb1_genome_length = gdb_to_length[gdb1_id]
                    gdb2_genome_length = gdb_to_length[gdb2_id]
                except KeyError:  # any key error here would prevent calculation of pairwise coverage
                    continue

                gdb_pair: Set = frozenset([gdb1_id, gdb2_id])
                mlss_pw_cov_info[mlss_id][gdb_pair] = (pw_cov_on_gdb1 + pw_cov_on_gdb2) / (
                    gdb2_genome_length + gdb2_genome_length
                )

    pw_to_ref_mlss = {}
    ref_mlss_reason = {}
    for pw_mlss_id in cactus_pw_mlss_ids:
        cand_ref_mlss_ids = [
            msa_mlss_id
            for msa_mlss_id in cactus_msa_mlss_ids
            if mlss_to_gdb_set[pw_mlss_id] <= mlss_to_gdb_set[msa_mlss_id]
        ]

        if len(cand_ref_mlss_ids) == 0:
            msg = f"no candidate reference MLSS found for pairwise Cactus MLSS {pw_mlss_id}"
            if args.on_missing_ref_mlss == "warn":
                warnings.warn(msg)
                continue
            raise RuntimeError(msg)  # args.on_missing_ref_mlss == "raise"

        if len(cand_ref_mlss_ids) == 1:
            ref_mlss_reason[pw_mlss_id] = "a single candidate"
            pw_to_ref_mlss[pw_mlss_id] = cand_ref_mlss_ids[0]
            continue

        gdb_pair = mlss_to_gdb_set[pw_mlss_id]
        if all(
            mlss_id in mlss_pw_cov_info and gdb_pair in mlss_pw_cov_info[mlss_id]
            for mlss_id in cand_ref_mlss_ids
        ):
            max_pw_cov = max(mlss_pw_cov_info[mlss_id][gdb_pair] for mlss_id in cand_ref_mlss_ids)
            cand_ref_mlss_ids = [
                mlss_id for mlss_id in cand_ref_mlss_ids if mlss_pw_cov_info[mlss_id][gdb_pair] == max_pw_cov
            ]
            if len(cand_ref_mlss_ids) == 1:
                ref_mlss_reason[pw_mlss_id] = "pairwise coverage"
                pw_to_ref_mlss[pw_mlss_id] = cand_ref_mlss_ids[0]
                continue

        min_mlss_size = min(mlss_to_size[mlss_id] for mlss_id in cand_ref_mlss_ids)
        cand_ref_mlss_ids = [
            mlss_id for mlss_id in cand_ref_mlss_ids if mlss_to_size[mlss_id] == min_mlss_size
        ]

        if len(cand_ref_mlss_ids) == 1:
            ref_mlss_reason[pw_mlss_id] = "MLSS size"
            pw_to_ref_mlss[pw_mlss_id] = cand_ref_mlss_ids[0]
        else:
            ref_mlss_reason[pw_mlss_id] = "MLSS ID"
            pw_to_ref_mlss[pw_mlss_id] = max(cand_ref_mlss_ids)

    tag_insert_statements = text(
        """\
            DELETE FROM
                method_link_species_set_tag
            WHERE
                method_link_species_set_id = :pw_mlss_id
            AND
                tag = 'alt_hal_mlss';
            INSERT INTO
                method_link_species_set_tag (method_link_species_set_id, tag, value)
            VALUES
                (:pw_mlss_id, 'alt_hal_mlss', :ref_mlss_id);
        """
    )

    url_update_statement = text(
        """\
            UPDATE
                method_link_species_set
            SET
                url = :mlss_url
            WHERE
                method_link_species_set_id = :mlss_id
        """
    )

    if args.dry_run:
        num_singletons = 0
        for pw_mlss_id, ref_mlss_id in pw_to_ref_mlss.items():
            if ref_mlss_reason[pw_mlss_id] == "a single candidate":
                num_singletons += 1
                continue
            print(
                f"Would link pairwise Cactus MLSS {pw_mlss_id} to reference MLSS {ref_mlss_id}"
                f" on the basis of {ref_mlss_reason[pw_mlss_id]} ..."
            )
        if num_singletons > 0:
            print(
                f"Would link the remaining {num_singletons} pairwise Cactus MLSSes"
                f" to their single available reference MLSS ..."
            )
    else:
        with engine.connect() as conn:
            for pw_mlss_id, ref_mlss_id in pw_to_ref_mlss.items():
                print(
                    f"Linking pairwise Cactus MLSS {pw_mlss_id} to reference MLSS {ref_mlss_id}"
                    f" on the basis of {ref_mlss_reason[pw_mlss_id]} ..."
                )
                conn.execute(
                    tag_insert_statements,
                    {"pw_mlss_id": pw_mlss_id, "ref_mlss_id": ref_mlss_id},
                )
                conn.execute(
                    url_update_statement,
                    {"mlss_id": pw_mlss_id, "mlss_url": cactus_msa_mlss_to_url[ref_mlss_id]},
                )
