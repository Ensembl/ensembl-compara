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
"""Download homology TSV file for specified genomes.

Homology TSV files are made available on Ensembl FTP sites.
Concatenated homology TSV files contain the complete set of
available homologies for a given gene-tree collection, while
genome-specific homology TSV files contain homologies relevant
to particular genomes.

To eliminate redundancy, each genome-specific homology TSV file
contains an arbitrary subset of orthologies involving the given
genome. To access all available orthologies between two or more
genomes, it is necessary to download the genome-specific files
of all the genomes, then filter them to keep relevant homologies.

This script facilitates access to genome-specific homology TSV
files. When provided with a list of genomes for a given Ensembl
release and Compara resource, it will identify the relevant set
of homology TSV files, then download those files, filter them,
and write relevant homologies to a user-specified output file.
"""

from argparse import ArgumentParser, RawTextHelpFormatter
from collections import defaultdict
from collections.abc import Sequence
import csv
from ftplib import FTP
import gzip
import hashlib
import logging
from pathlib import Path
import re
import shutil
from string import Template
import sys
from tempfile import NamedTemporaryFile, TemporaryDirectory
import traceback
from typing import Any, Optional, Union
from urllib.parse import urlunparse
from urllib.request import urlopen


_EG_RELEASE_OFFSET = 53
_PAN_REDUB_RELEASE = 114
_REQUEST_TIMEOUT = 60

_FTP_META: dict[str, dict[str, Any]] = {
    "fungi": {
        "host": "ftp.ensemblgenomes.ebi.ac.uk",
        "path_prefix_template": "pub/fungi/release-${eg_version}",
        "current_path_prefix": "pub/fungi/current",
        "min_ensembl_version": 98,
        "min_eg_version": 45,
    },
    "metazoa": {
        "host": "ftp.ensemblgenomes.ebi.ac.uk",
        "path_prefix_template": "pub/metazoa/release-${eg_version}",
        "current_path_prefix": "pub/metazoa/current",
        "min_ensembl_version": 114,
        "min_eg_version": 61,
    },
    "pan_homology": {
        "host": "ftp.ensemblgenomes.ebi.ac.uk",
        "path_prefix_template": "pub/release-${eg_version}/${pan_ensembl}",
        "current_path_prefix": "pub/current/pan",
        "min_ensembl_version": 97,
        "min_eg_version": 44,
    },
    "plants": {
        "host": "ftp.ensemblgenomes.ebi.ac.uk",
        "path_prefix_template": "pub/plants/release-${eg_version}",
        "current_path_prefix": "pub/plants/current",
        "min_ensembl_version": 114,
        "min_eg_version": 61,
    },
    "protists": {
        "host": "ftp.ensemblgenomes.ebi.ac.uk",
        "path_prefix_template": "pub/protists/release-${eg_version}",
        "current_path_prefix": "pub/protists/current",
        "min_ensembl_version": 97,
        "min_eg_version": 44,
    },
    "vertebrates": {
        "host": "ftp.ensembl.org",
        "path_prefix_template": "pub/release-${ensembl_version}",
        "current_path_prefix": "pub/current",
        "min_ensembl_version": 114,
    },
}

_COMPARA_NAMES = list(_FTP_META.keys())


class HomologyTSV(csv.Dialect):
    """Homology TSV dialect."""

    delimiter = "\t"
    lineterminator = "\n"
    quoting = csv.QUOTE_NONE
    strict = False


def compose_url(scheme: str, netloc: str, path: str) -> str:
    """Return URL composed from input arguments."""
    return urlunparse([scheme, netloc, path, "", "", ""])


def compute_file_md5sum(file_path):
    """Compute MD5 hex digest of the specified file.

    Args:
        file_path: Path of file for which an MD5 digest should be computed.

    Returns:
        MD5SUM hex digest.
    """
    m = hashlib.md5()
    with open(file_path, mode="rb") as in_file_obj:
        while chunk := in_file_obj.read(1048576):
            m.update(chunk)
    return m.hexdigest()


# pylint: disable-next=too-many-branches
def download_homology_tsv_set(
    hom_tsv_file_set: list[dict], genome_names: Sequence[str], output_file: str
) -> None:
    """Download TSV file of homologies involving specified genome(s).

    Args:
        hom_tsv_file_set: Sequence of homology TSV file records containing
            the set of homologies between the given genomes. Each file must
            be represented by a mapping, which must have "file_url" and
            "file_size" entries, and may have an "md5sum_file_url" entry.
        genome_names: Sequence of names of one or more genomes for which
            homologies should be downloaded.
        output_file: Output homology TSV file path.

    Raises:
        RuntimeError: If a downloaded file has an unexpected file size
            or MD5 digest, or if downloaded files have inconsistent
            column names.
    """
    out_file_path = Path(output_file)

    with TemporaryDirectory(prefix="tmp_hom_tsv_", dir=out_file_path.parent) as tmp_dir:
        tmp_dir_path = Path(tmp_dir)

        hom_tsv_file_set = sorted(hom_tsv_file_set, key=lambda file_rec: file_rec["file_size"], reverse=True)

        logging.info("opening temp output homology TSV file")
        tmp_out_file_path = tmp_dir_path / out_file_path.name
        with gzip.open(tmp_out_file_path, mode="xt", encoding="utf-8", newline="") as out_file_obj:
            writer = csv.writer(out_file_obj, dialect=HomologyTSV)

            hom_tsv_col_names = None
            species_col_idx = None
            hom_species_col_idx = None
            for file_rec in hom_tsv_file_set:
                file_url = file_rec["file_url"]
                spec_file_size = file_rec["file_size"]

                *_dl_file_path, dl_file_name = file_url.rsplit("/", maxsplit=1)
                tmp_in_file_path = tmp_dir_path / dl_file_name

                logging.info("downloading homology TSV file from %s", file_url)
                with (
                    urlopen(file_url, timeout=_REQUEST_TIMEOUT) as response,
                    NamedTemporaryFile(
                        mode="wb", suffix=f"_{dl_file_name}", dir=tmp_dir_path, delete=False
                    ) as tmp_file_obj,
                ):
                    tmp_in_file_path = Path(tmp_file_obj.name)
                    shutil.copyfileobj(response, tmp_file_obj)
                    headers = dict(response.info())

                if "Content-Length" in headers:
                    exp_file_size = int(headers["Content-Length"])
                    if exp_file_size != spec_file_size:
                        logging.warning(
                            "download request header 'Content-Length' "
                            "(%d) does not match specified file size (%d)",
                            exp_file_size,
                            spec_file_size,
                        )
                else:
                    exp_file_size = spec_file_size

                logging.info("checking download file size")
                obs_file_size = tmp_in_file_path.stat().st_size
                if obs_file_size != exp_file_size:
                    raise RuntimeError(
                        f"download file size ({obs_file_size})"
                        f" does not match expected file size ({exp_file_size})"
                    )

                if "md5sum_file_url" in file_rec:
                    logging.info("checking download file MD5SUM")
                    md5sum_file_url = file_rec["md5sum_file_url"]
                    logging.debug("fetching precomputed MD5SUM from %s", md5sum_file_url)
                    precomputed_file_md5sum = fetch_precomputed_file_md5sum(md5sum_file_url, dl_file_name)
                    if precomputed_file_md5sum:
                        logging.debug("computing MD5SUM of download file")
                        tmp_in_file_md5sum = compute_file_md5sum(tmp_in_file_path)
                        if tmp_in_file_md5sum == precomputed_file_md5sum:
                            logging.debug("download file MD5 digest matches precomputed MD5SUM")
                        else:
                            raise RuntimeError(
                                f"downloaded file MD5 digest ({tmp_in_file_md5sum})"
                                f" does not match precomputed MD5SUM ({precomputed_file_md5sum})"
                            )
                    else:
                        logging.warning("failed to fetch precomputed MD5SUM, skipping MD5 check")

                logging.info("copying relevant homologies")
                with gzip.open(tmp_in_file_path, mode="rt", encoding="utf-8", newline="") as in_file_obj:
                    reader = csv.reader(in_file_obj, dialect=HomologyTSV)
                    tmp_in_file_col_names = next(reader)
                    if hom_tsv_col_names is None:
                        hom_tsv_col_names = tmp_in_file_col_names
                        writer.writerow(hom_tsv_col_names)
                        species_col_idx = hom_tsv_col_names.index("species")
                        hom_species_col_idx = hom_tsv_col_names.index("homology_species")
                    elif tmp_in_file_col_names != hom_tsv_col_names:
                        raise RuntimeError(
                            "cannot concatenate homology TSV files due to inconsistent column names"
                        )

                    assert (
                        species_col_idx is not None
                    ), "'species' column index required to filter homologies by genome"
                    assert (
                        hom_species_col_idx is not None
                    ), "'homology_species' column index required to filter homologies by genome"

                    for row in reader:
                        if (
                            row[species_col_idx] not in genome_names
                            or row[hom_species_col_idx] not in genome_names
                        ):  # pylint: disable=possibly-used-before-assignment
                            continue
                        writer.writerow(row)

        logging.info("writing final output homology TSV file")
        shutil.move(tmp_out_file_path, out_file_path)


def fetch_precomputed_file_md5sum(md5sum_file_url: str, file_name: str) -> Union[str, None]:
    """Fetch precomputed MD5 digest of the specified file.

    Args:
        md5sum_file_url: URL of MD5SUM file.
        file_name: Name of file for which an MD5 digest should be retrieved.

    Returns:
        MD5SUM hex digest, if available for the specifed file; otherwise None.
    """
    with urlopen(md5sum_file_url, timeout=_REQUEST_TIMEOUT) as response:
        data = response.read()
        text = data.decode("utf-8")
        for line in text.splitlines():
            computed_file_md5sum, checksummed_file_name = line.split(maxsplit=1)
            if checksummed_file_name == file_name:
                return computed_file_md5sum
    return None


# pylint: disable-next=too-many-branches
def find_homology_tsv_file_sets(
    genome_names: Sequence[str],
    compara: str,
    release: Optional[int] = None,
    member_type: str = "protein",
    clusterset_id: Optional[str] = None,
) -> dict[str, list[dict]]:
    """Find homology TSV file sets.

    Args:
        genome_names: Names of genomes for which homologies should be found.
        compara: Compara resource.
        release: Ensembl release (default: current).
        member_type: Member sequence type.
        clusterset_id: If specified, this must be the clusterset_id of the
            gene-tree collection from which homologies should be taken.

    Returns:
        Mapping of label to homology TSV file set, where each file set
        contains the set of homologies between the given genomes.

    Raises:
        RuntimeError: If this script does not support the given Ensembl
            release and Compara resource, or if homology TSV directories
            cannot be found for all specified genomes.
    """
    compara_ftp_meta = _FTP_META[compara]

    if release:
        path_prefix_template = Template(compara_ftp_meta["path_prefix_template"])
        pan_ensembl = "pan" if release >= _PAN_REDUB_RELEASE else "pan_ensembl"
        eg_version = release - _EG_RELEASE_OFFSET
        path_prefix = path_prefix_template.substitute(
            eg_version=eg_version,
            ensembl_version=release,
            pan_ensembl=pan_ensembl,
        )

        min_ensembl_version = compara_ftp_meta["min_ensembl_version"]
        if release < min_ensembl_version:
            raise RuntimeError(
                f"cannot get {compara} homology TSV files for Ensembl"
                f" release {release} (min={min_ensembl_version})"
            )
    else:
        path_prefix = compara_ftp_meta["current_path_prefix"]

    host = compara_ftp_meta["host"]
    tsv_dir_path = f"{path_prefix}/tsv/ensembl-compara/homologies"

    hom_tsv_file_re = re.compile(
        r"Compara\.[0-9]+\.(?P<member_type>protein|ncrna)_(?P<clusterset_id>[^.]+)\.homologies\.tsv\.gz"
    )
    collection_name_re = re.compile(r"(?:bacteria|fungi|protists)_.+?_collection")

    with FTP(host) as ftp:
        ftp.login()

        ftp.cwd(tsv_dir_path)
        tsv_dir_item_names = ftp.nlst()

        if "MD5SUM" in tsv_dir_item_names:
            main_md5sum_file_url = compose_url("https", host, f"{tsv_dir_path}/MD5SUM")
        else:
            main_md5sum_file_url = None

        gdb_dir_recs = {k: {} for k in genome_names}  # type: ignore
        genomes_to_find = set(genome_names)

        main_hom_tsvs_by_cset_id = {}
        collection_dir_rel_paths = []
        for item_name in tsv_dir_item_names:
            if item_name in genomes_to_find:
                gdb_dir_recs[item_name]["rel_path"] = item_name
                genomes_to_find.remove(item_name)
            elif match := hom_tsv_file_re.fullmatch(item_name):
                file_cset_id = match["clusterset_id"]
                if match["member_type"] != member_type or (clusterset_id and file_cset_id != clusterset_id):
                    continue

                main_rec = {
                    "file_url": compose_url("https", host, f"{tsv_dir_path}/{item_name}"),
                    "file_size": ftp.size(item_name),
                }

                if main_md5sum_file_url:
                    main_rec["md5sum_file_url"] = main_md5sum_file_url

                main_hom_tsvs_by_cset_id[file_cset_id] = main_rec

            elif collection_name_re.fullmatch(item_name):
                collection_dir_rel_paths.append(item_name)

        while genomes_to_find:
            try:
                collection_dir_rel_path = collection_dir_rel_paths.pop()
            except IndexError as exc:
                raise RuntimeError(
                    f"failed to find homology TSV directories for genomes: {','.join(genomes_to_find)}"
                ) from exc

            ftp.cwd(collection_dir_rel_path)
            collection_dir_item_names = ftp.nlst()
            for item_name in collection_dir_item_names:
                if item_name in genomes_to_find:
                    gdb_dir_recs[item_name]["rel_path"] = f"{collection_dir_rel_path}/{item_name}"
                    genomes_to_find.remove(item_name)
            ftp.cwd(f"/{tsv_dir_path}")

        gdb_hom_tsvs_by_cset_id = defaultdict(dict)  # type: ignore
        for genome_name in genome_names:
            gdb_dir_rel_path = gdb_dir_recs[genome_name]["rel_path"]
            gdb_dir_path = f"{tsv_dir_path}/{gdb_dir_rel_path}"

            ftp.cwd(gdb_dir_rel_path)
            gdb_dir_item_names = ftp.nlst()

            if "MD5SUM" in gdb_dir_item_names:
                gdb_md5sum_file_url = compose_url("https", host, f"{gdb_dir_path}/MD5SUM")
            else:
                gdb_md5sum_file_url = None

            for item_name in gdb_dir_item_names:
                if match := hom_tsv_file_re.fullmatch(item_name):
                    file_cset_id = match["clusterset_id"]
                    if match["member_type"] != member_type or (
                        clusterset_id and file_cset_id != clusterset_id
                    ):
                        continue

                    gdb_rec = {
                        "file_url": compose_url("https", host, f"{gdb_dir_path}/{item_name}"),
                        "file_size": ftp.size(item_name),
                    }

                    if gdb_md5sum_file_url:
                        gdb_rec["md5sum_file_url"] = gdb_md5sum_file_url

                    gdb_hom_tsvs_by_cset_id[file_cset_id][genome_name] = gdb_rec

            ftp.cwd(f"/{tsv_dir_path}")

    usable_cset_ids = [
        k for k in gdb_hom_tsvs_by_cset_id if len(gdb_hom_tsvs_by_cset_id[k]) == len(genome_names)
    ]

    hom_tsv_file_sets = {}
    for cset_id in usable_cset_ids:
        main_key = f"concatenated {cset_id} homologies"
        hom_tsv_file_sets[main_key] = [main_hom_tsvs_by_cset_id[cset_id]]

        gdb_key = f"per-genome {cset_id} homologies"
        hom_tsv_file_sets[gdb_key] = list(gdb_hom_tsvs_by_cset_id[cset_id].values())

    return hom_tsv_file_sets


def print_homology_tsv_set_urls(hom_tsv_file_set):
    """Print URLs of files in the given homology TSV set.

    Args:
        hom_tsv_file_set: Sequence of homology TSV file records containing
            the set of homologies between the given genomes.
    """
    for file_rec in hom_tsv_file_set:
        print(file_rec["file_url"])


def select_homology_tsv_file_set(hom_tsv_file_sets: dict[str, list[dict]]) -> list[dict]:
    """Select homology TSV file set with lowest total file size.

    Args:
        hom_tsv_file_sets: Mapping of label to homology TSV file set, where each
            file set includes the set of homologies between the given genomes.

    Returns:
        Selected homology TSV file set.
    """

    def total_file_size(hom_tsv_file_set):
        return sum(file_rec["file_size"] for file_rec in hom_tsv_file_set)

    chosen_key = min(hom_tsv_file_sets, key=lambda k: total_file_size(hom_tsv_file_sets[k]))

    logging.info("selected %s", chosen_key)
    return hom_tsv_file_sets[chosen_key]


def main():
    """Main function of script."""

    parser = ArgumentParser(description=__doc__, formatter_class=RawTextHelpFormatter)

    genome_group = parser.add_mutually_exclusive_group(required=True)
    genome_group.add_argument("--genome-list", metavar="STR", help="Comma-separated list of genome names.")
    genome_group.add_argument(
        "--genome-list-file", metavar="PATH", help="Text file listing genome names, one per line."
    )

    parser.add_argument("--compara", choices=_COMPARA_NAMES, required=True, help="Ensembl Compara resource.")

    release_group = parser.add_mutually_exclusive_group()
    release_group.add_argument(
        "--release", metavar="INT", type=int, help="Ensembl release (default: current)."
    )
    release_group.add_argument(
        "--eg-release", metavar="INT", type=int, help="Ensembl Genomes release (default: current)."
    )

    parser.add_argument("--clusterset-id", metavar="STR", help="Gene-tree collection clusterset ID.")
    parser.add_argument(
        "--member-type",
        choices=("protein", "ncrna"),
        default="protein",
        help="Member sequence type (default: 'protein').",
    )

    output_group = parser.add_mutually_exclusive_group(required=True)
    output_group.add_argument("-o", "--output-file", metavar="PATH", help="Output homology TSV file.")
    output_group.add_argument(
        "--dry-run",
        action="store_true",
        help="Print URLs of relevant homology TSV files to\nstandard output, but do not download them.",
    )

    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        default="WARNING",
        help="Log level (default: 'WARNING').",
    )

    args = parser.parse_args()

    logging.basicConfig(
        format="%(asctime)s - %(filename)s - %(message)s",
        level=args.log_level,
        stream=sys.stderr,
    )

    if args.genome_list_file:
        with open(args.genome_list_file, encoding="utf-8") as in_file_obj:
            genomes = sorted(line.rstrip() for line in in_file_obj)
    else:
        genomes = sorted(args.genome_list.split(","))

    if args.eg_release:
        ensembl_release = args.eg_release + _EG_RELEASE_OFFSET
    else:
        ensembl_release = args.release

    display_release = f"release {ensembl_release}" if ensembl_release else "current release"
    logging.info("finding homology TSV file sets for %s", display_release)
    homology_tsv_file_sets = find_homology_tsv_file_sets(
        genomes,
        args.compara,
        release=ensembl_release,
        member_type=args.member_type,
        clusterset_id=args.clusterset_id,
    )

    if not homology_tsv_file_sets:
        raise RuntimeError("no homology TSV file sets found matching specified parameters")

    logging.info("selecting homology TSV file set")
    homology_tsv_file_set = select_homology_tsv_file_set(homology_tsv_file_sets)

    if args.dry_run:
        print_homology_tsv_set_urls(homology_tsv_file_set)
    else:
        if not args.output_file.endswith(".gz"):
            raise ValueError("output file must have extension '.gz'")

        logging.info("downloading selected homology TSV file set")
        download_homology_tsv_set(homology_tsv_file_set, genomes, args.output_file)

        logging.info("download complete")


if __name__ == "__main__":

    try:
        main()
    except Exception:  # pylint: disable=broad-exception-caught
        logging.exception(traceback.format_exc())
        sys.exit(1)
