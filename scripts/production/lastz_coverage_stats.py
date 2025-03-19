#!/usr/bin/env python3
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""This script obtains lastz coverage statistics for a release or lastz db. 

To get relevant statistics from release DB use the --release flag. 

Example command:
    #Lastz db:
    ./lastz_coverage_stats.py url output_file
    #Release db:
   ./lastz_coverage_stats.py url output_file --release release_version
"""

import argparse
import csv
from collections import defaultdict

from sqlalchemy import create_engine, text


get_lastz_mlss_from_first_release = """
    SELECT 
        method_link_species_set_id
    FROM 
        method_link_species_set
    WHERE 
        method_link_id = 16
    AND 
        first_release = :release;
    """

# The method_link_id 16 is intended to match LASTZ_NET method_link_type in this script.
get_mlss_for_rerun_tags = """
    SELECT 
        mlss_tag.method_link_species_set_id
    FROM 
        method_link_species_set_tag AS mlss_tag
    INNER JOIN
        method_link_species_set AS mlss
    USING 
        (method_link_species_set_id)
    WHERE 
        mlss_tag.tag IN (:rerun_tag, :patched_tag) 
    AND 
        mlss.method_link_id = 16;
    """


get_mlss_from_lastz_db = """
    SELECT 
        method_link_species_set_id 
    FROM 
        method_link_species_set 
    WHERE 
        method_link_id = 16;
    """


get_query_for_results = """
    SELECT 
        method_link_species_set_id,
        tag,
        value
    FROM
        method_link_species_set_tag 
    WHERE
        method_link_species_set_id IN :mlss_ids
    AND
        tag IN (
            'reference_species', 
            'ref_genome_coverage', 
            'ref_genome_length', 
            'non_reference_species', 
            'non_ref_genome_coverage', 
            'non_ref_genome_length'
        );
    """


def calculate_coverage_ratios(results):
    """
    Calculate the coverage ratios from the query results and create a nested dictionary.

    Args:
        results: The query results.

    Returns:
        A list of dictionaries with the calculated coverage ratios.
    """
    data = defaultdict(dict)
    for mlss, tag, value in results:
        data[mlss][tag] = value

    calculated_results = []
    for mlss, tags in data.items():
        ref_genome_coverage = tags.get("ref_genome_coverage")
        ref_genome_length = tags.get("ref_genome_length")
        if ref_genome_coverage is not None and ref_genome_length is not None:
            ref_coverage_ratio = (
                int(ref_genome_coverage) / int(ref_genome_length)
            ) * 100
        else:
            ref_coverage_ratio = float("nan")

        non_ref_genome_coverage = tags.get("non_ref_genome_coverage")
        non_ref_genome_length = tags.get("non_ref_genome_length")
        if non_ref_genome_coverage is not None and non_ref_genome_length is not None:
            non_ref_coverage_ratio = (
                int(non_ref_genome_coverage) / int(non_ref_genome_length)
            ) * 100
        else:
            non_ref_coverage_ratio = float("nan")

        calculated_results.append(
            {
                "mlss": mlss,
                "reference_species": tags.get("reference_species"),
                "ref_genome_coverage": tags.get("ref_genome_coverage"),
                "ref_coverage_ratio": round(ref_coverage_ratio, 4),
                "non_reference_species": tags.get("non_reference_species"),
                "non_ref_genome_coverage": tags.get("non_ref_genome_coverage"),
                "non_ref_coverage_ratio": round(non_ref_coverage_ratio, 4),
            }
        )

    return calculated_results


def write_to_tsv(filename, results):
    """
    Write the calculated results to a TSV file.

    Args:
        filename: The name of the TSV file.
        results: The calculated results to write.
    """
    with open(filename, "w", newline="", encoding="utf-8") as tsvfile:
        writer = csv.writer(tsvfile, delimiter="\t")
        writer.writerow(
            [
                "mlss",
                "reference_species",
                "ref_genome_coverage",
                "ref_coverage_ratio",
                "non_reference_species",
                "non_ref_genome_coverage",
                "non_ref_coverage_ratio",
            ]
        )
        for row in results:
            writer.writerow(
                [
                    row["mlss"],
                    row["reference_species"],
                    row["ref_genome_coverage"],
                    row["ref_coverage_ratio"],
                    row["non_reference_species"],
                    row["non_ref_genome_coverage"],
                    row["non_ref_coverage_ratio"],
                ]
            )


def process_database(url, output_file, release=None):
    """
    Process the database to retrieve coverage ratios and write the result to a TSV file.

    Args:
        url: The database URL.
        output_file: The name of the output TSV file.
        release: The release version (optional).
    """
    engine = create_engine(url)
    with engine.connect() as connection:
        if release is None:
            initial_result = connection.execute(text(get_mlss_from_lastz_db))
            mlss_ids = [row[0] for row in initial_result]

        else:
            param_release = {"release": release}

            get_first_release_ids = connection.execute(
                text(get_lastz_mlss_from_first_release), param_release
            )
            mlss_ids = [row[0] for row in get_first_release_ids]

            params_rerun_tags = {
                "rerun_tag": f"rerun_in_{release}",
                "patched_tag": f"patched_in_{release}",
            }
            get_rerun_mlsses = connection.execute(
                text(get_mlss_for_rerun_tags), params_rerun_tags
            )
            mlss_ids.extend([row[0] for row in get_rerun_mlsses])

        if mlss_ids:
            param_ids = {"mlss_ids": mlss_ids}
            result_query = connection.execute(text(get_query_for_results), param_ids)
            calculated_results = calculate_coverage_ratios(result_query)
            write_to_tsv(output_file, calculated_results)


def main():
    """
    Main function to parse user input and process the database.
    """
    parser = argparse.ArgumentParser(
        description="Process database and write coverage ratios to TSV file."
    )
    parser.add_argument("url", type=str, help="The database URL.")
    parser.add_argument(
        "output_file", type=str, help="The name of the output TSV file."
    )
    parser.add_argument(
        "--release", type=int, default=None, help="The release version (optional)."
    )
    args = parser.parse_args()

    process_database(args.url, args.output_file, args.release)


if __name__ == "__main__":
    main()
