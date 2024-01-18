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
"""Create symlinks to previously dumped Compara data files."""

import argparse
import json
import os
from pathlib import Path
import shutil
from tempfile import TemporaryDirectory


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--curr_ftp_dump_root", required=True, help="Main dump root directory of the current Ensembl release."
    )
    parser.add_argument(
        "--prev_ftp_dump_root", required=True, help="Main dump root directory of previous Ensembl release."
    )
    parser.add_argument(
        "--curr_ftp_pub_root", required=True, help="FTP publication root directory of current release."
    )
    parser.add_argument(
        "--prev_ftp_pub_root", required=True, help="FTP publication root directory of previous release."
    )
    parser.add_argument(
        "--mlss_path_type", required=True, choices=["archive", "directory"], help="MLSS path type."
    )
    parser.add_argument(
        "--mlss_path", required=True, help="MLSS dump path relative to the main dump root directory."
    )
    parser.add_argument("--mlss_id", required=True, help="MLSS ID of dumped data.")
    parser.add_argument("--dataflow_file", required=True, help="Output JSON file to dataflow missing MLSSes.")

    args = parser.parse_args()

    curr_ftp_dump_root = Path(args.curr_ftp_dump_root)
    prev_ftp_dump_root = Path(args.prev_ftp_dump_root)
    curr_ftp_pub_root = Path(args.curr_ftp_pub_root)
    prev_ftp_pub_root = Path(args.prev_ftp_pub_root)
    mlss_path = Path(args.mlss_path)
    dataflow_file = Path(args.dataflow_file)

    known_standin_mlss_ids = ["ANCESTRAL_ALLELES"]
    try:
        mlss_id = int(args.mlss_id)
    except ValueError as exc:
        if args.mlss_id in known_standin_mlss_ids:
            mlss_id = args.mlss_id
        else:
            raise ValueError(f"invalid MLSS ID: {args.mlss_id}") from exc

    if not curr_ftp_dump_root.is_absolute():
        raise ValueError(
            f"value of --curr_ftp_dump_root must be an absolute path,"
            f" but appears to be relative: {str(curr_ftp_dump_root)!r}"
        )
    if not prev_ftp_dump_root.is_absolute():
        raise ValueError(
            f"value of --prev_ftp_dump_root must be an absolute path,"
            f" but appears to be relative: {str(prev_ftp_dump_root)!r}"
        )
    if not curr_ftp_pub_root.is_absolute():
        raise ValueError(
            f"value of --curr_ftp_pub_root must be an absolute path,"
            f" but appears to be relative: {str(curr_ftp_pub_root)!r}"
        )
    if not prev_ftp_pub_root.is_absolute():
        raise ValueError(
            f"value of --prev_ftp_pub_root must be an absolute path,"
            f" but appears to be relative: {str(prev_ftp_pub_root)!r}"
        )

    if args.mlss_path_type == "archive":
        root_to_mlss_dir_path = mlss_path.parent
        path_spec = f"{mlss_path.name}*"
    elif args.mlss_path_type == "directory":
        root_to_mlss_dir_path = mlss_path
        path_spec = "*"

    prev_mlss_dir_path = prev_ftp_dump_root / root_to_mlss_dir_path
    prev_mlss_file_paths = list(prev_mlss_dir_path.glob(path_spec))

    if args.mlss_path_type == "archive" and len(prev_mlss_file_paths) > 1:
        raise RuntimeError(
            f"path spec {path_spec!r} matches multiple archive files in directory {str(prev_mlss_dir_path)!r}"
        )

    dataflow_events = []
    if prev_mlss_file_paths:
        curr_to_prev_root_path = Path(os.path.relpath(prev_ftp_pub_root, start=curr_ftp_pub_root))
        curr_mlss_dir_path = curr_ftp_dump_root / root_to_mlss_dir_path
        mlss_dir_to_root_parent = os.path.relpath(curr_ftp_dump_root, start=curr_mlss_dir_path)

        symlink_pairs = []
        for prev_mlss_file_path in prev_mlss_file_paths:
            root_to_mlss_file_path = root_to_mlss_dir_path / prev_mlss_file_path.name
            new_symlink_target = mlss_dir_to_root_parent / curr_to_prev_root_path / root_to_mlss_file_path

            if prev_mlss_file_path.is_symlink():
                prev_symlink_target = Path(os.readlink(prev_mlss_file_path))
                if not prev_symlink_target.is_absolute():
                    new_symlink_target = Path(os.path.normpath(new_symlink_target.parent / prev_symlink_target))

            curr_mlss_file_path = curr_ftp_dump_root / root_to_mlss_file_path
            symlink_pairs.append((new_symlink_target, curr_mlss_file_path))

        with TemporaryDirectory(dir=curr_mlss_dir_path, prefix=".symlink_tmp_") as tmp_dir:
            for new_symlink_target, curr_mlss_file_path in symlink_pairs:
                tmp_mlss_file_path = os.path.join(tmp_dir, curr_mlss_file_path.name)
                os.symlink(new_symlink_target, tmp_mlss_file_path)
                shutil.move(tmp_mlss_file_path, curr_mlss_file_path)
    else:
        # We cannot currently dataflow standin MLSS IDs.
        if mlss_id in known_standin_mlss_ids:
            raise RuntimeError(
                f"cannot symlink {mlss_id} data - file not found in"
                f" previous release dump {str(prev_ftp_dump_root)!r}"
            )
        dataflow_branch = 2
        dataflow_json = json.dumps({"missing_mlss_id": args.mlss_id})
        dataflow_events.append(f"{dataflow_branch} {dataflow_json}")

    os.makedirs(dataflow_file.parent, mode=0o775, exist_ok=True)
    with open(dataflow_file, "w") as out_file_obj:
        for dataflow_event in dataflow_events:
            print(dataflow_event, file=out_file_obj)
