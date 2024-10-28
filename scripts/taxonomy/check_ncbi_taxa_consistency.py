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
"""Check consistency of Ensembl NCBI Taxonomy databases."""

import argparse
from collections import defaultdict
import subprocess

from sqlalchemy import create_engine, text



if __name__ == "__main__":

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", type=int, help="Current Ensembl release.")
    parser.add_argument(
        "--hosts", help="Comma-separated list of hosts on which the NCBI Taxonomy database may be found."
    )
    args = parser.parse_args()

    db_name = f"ncbi_taxonomy_{args.release}"
    hosts = args.hosts.split(",")

    db_query = text("""SHOW DATABASES LIKE :db_name""")

    ncbi_taxa_urls = []
    for host in hosts:
        cmd_args = [host, "details", "url"]

        output = subprocess.check_output(cmd_args, text=True)

        host_url = output.rstrip()
        engine = create_engine(host_url)
        with engine.connect() as conn:
            db_found = conn.execute(db_query, {"db_name": db_name}).scalar_one_or_none()

        if db_found:
            ncbi_taxa_urls.append(f"{host_url}{db_name}")

    if not ncbi_taxa_urls:
        raise RuntimeError("no NCBI Taxonomy databases found")

    import_date_query = text(
        """\
        SELECT name FROM ncbi_taxa_name
        WHERE name_class = 'import date'
    """
    )

    dbs_by_import_date = defaultdict(list)
    for ncbi_taxa_url in ncbi_taxa_urls:
        engine = create_engine(ncbi_taxa_url)
        with engine.connect() as conn:
            import_date = conn.execute(import_date_query).scalar_one()
            dbs_by_import_date[import_date].append(engine.url)

    if len(dbs_by_import_date) > 1:
        raise RuntimeError(
            f"NCBI Taxonomy databases have inconsistent import dates: {sorted(dbs_by_import_date)}"
        )
