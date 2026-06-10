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
"""Compare regions in two Enredo output files."""

from argparse import ArgumentParser
from collections import defaultdict
import csv
from pathlib import Path
import re
from tempfile import TemporaryDirectory

from pybedtools import BedTool


def extract_enredo_regions(enredo_out_file_path: Path, out_dir_path: Path) -> dict[str, Path]:
    """Extract regions from an Enredo output file."""
    enredo_region_re = re.compile(
        "(?P<prod_name>_?[a-z0-9]+_[a-z0-9_]+)"
        ":(?P<dnafrag_name>.+?)"
        ":(?P<dnafrag_start>[0-9]+)"
        ":(?P<dnafrag_end>[0-9]+)"
        "\\s+"
    )

    regions_by_genome = defaultdict(list)
    with open(enredo_out_file_path, encoding="ascii") as in_file_obj:
        for line in in_file_obj:
            if line.startswith(("#", "block")):
                continue
            if match := enredo_region_re.match(line):
                prod_name = match["prod_name"]
                chrom_name = match["dnafrag_name"]
                chrom_start = int(match["dnafrag_start"]) - 1
                chrom_end = int(match["dnafrag_end"])
                regions_by_genome[prod_name].append((chrom_name, chrom_start, chrom_end))

    bed_file_map = {}
    for prod_name, regions in regions_by_genome.items():
        bed_file_path = out_dir_path / f"{prod_name}.bed"
        with open(bed_file_path, mode="w", encoding="utf-8", newline="") as out_file_obj:
            writer = csv.writer(out_file_obj, delimiter="\t", lineterminator="\n")
            for region in sorted(regions):
                writer.writerow(region)
        bed_file_map[prod_name] = bed_file_path

    return bed_file_map


def main() -> None:
    """Main function of script."""

    parser = ArgumentParser(description=__doc__)
    parser.add_argument("-a", dest="file1", required=True, help="First Enredo output file to compare.")
    parser.add_argument("-b", dest="file2", required=True, help="Second Enredo output file to compare.")
    parser.add_argument("-o", "--output-file", required=True, help="Output TSV file of comparison results.")

    args = parser.parse_args()

    enredo_out_file_paths = [Path(x) for x in (args.file1, args.file2)]

    recs = []
    with TemporaryDirectory() as tmp_dir:
        tmp_dir_path = Path(tmp_dir)

        bed_file_maps = []
        for dataset_idx, enredo_out_file_path in enumerate(enredo_out_file_paths):
            bed_dir_path = tmp_dir_path / str(dataset_idx)
            bed_dir_path.mkdir()
            dataset_bed_file_map = extract_enredo_regions(enredo_out_file_path, bed_dir_path)
            bed_file_maps.append(dataset_bed_file_map)

        bed_file_map1, bed_file_map2 = bed_file_maps  # pylint: disable=unbalanced-tuple-unpacking
        prod_names = sorted(bed_file_map1.keys() | bed_file_map2.keys())
        for prod_name in prod_names:
            bed_file_path1 = bed_file_map1[prod_name]
            bed_file_path2 = bed_file_map2[prod_name]
            bedtool = BedTool(bed_file_path1)
            rec = bedtool.jaccard(str(bed_file_path2))  # pylint: disable=too-many-function-args
            rec["genome_name"] = prod_name
            recs.append(rec)

    out_col_names = [
        "genome_name",
        "n_intersections",
        "intersection",
        "union",
        "jaccard",
    ]

    with open(args.output_file, mode="w", encoding="utf-8", newline="") as out_file_obj:
        writer = csv.DictWriter(out_file_obj, out_col_names, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for rec in recs:
            writer.writerow(rec)


if __name__ == "__main__":
    main()
