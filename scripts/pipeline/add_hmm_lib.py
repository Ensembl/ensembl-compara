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
"""Add HMM library archive to flat-file dump."""

import argparse
import os
from pathlib import Path
import subprocess
import shutil
from tempfile import TemporaryDirectory


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--curr_ftp_dump_root",
        required=True,
        help="Main dump root directory of the current Ensembl release.",
    )
    parser.add_argument(
        "--prev_ftp_dump_root",
        required=True,
        help="Main dump root directory of previous Ensembl release.",
    )
    parser.add_argument(
        "--curr_ftp_pub_root",
        required=True,
        help="FTP publication root directory of current release.",
    )
    parser.add_argument(
        "--prev_ftp_pub_root",
        required=True,
        help="FTP publication root directory of previous release.",
    )
    parser.add_argument(
        "--hmm_library_basedir",
        required=True,
        help="Path of HMM library base directory.",
    )
    parser.add_argument(
        "--ref_tar_path_templ",
        required=True,
        help="Template of reference HMM library tar archive path.",
    )
    parser.add_argument(
        "--tar_dir_path",
        required=True,
        help="Path of directory containing archive, relative to the main dump root directory.",
    )
    args = parser.parse_args()

    curr_ftp_dump_root = Path(args.curr_ftp_dump_root)
    prev_ftp_dump_root = Path(args.prev_ftp_dump_root)
    curr_ftp_pub_root = Path(args.curr_ftp_pub_root)
    prev_ftp_pub_root = Path(args.prev_ftp_pub_root)
    hmm_library_basedir = Path(args.hmm_library_basedir)
    tar_dir_path = Path(args.tar_dir_path)

    library_name = hmm_library_basedir.name
    ref_tar_path = Path(args.ref_tar_path_templ % library_name)
    ref_tar_md5sum_path = ref_tar_path.with_suffix(".gz.md5sum")

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
    if tar_dir_path.is_absolute():
        raise ValueError(
            f"value of --tar_dir_path must be a relative path,"
            f" but appears to be absolute: {str(tar_dir_path)!r}"
        )

    with TemporaryDirectory() as tmp_dir:
        tmp_dir_path = Path(tmp_dir)

        tar_file_confirmed_ok = False
        if ref_tar_path.is_file():

            md5sum_check_cmd_args = ["md5sum", "--check", str(ref_tar_md5sum_path)]
            try:
                output = subprocess.check_output(
                    md5sum_check_cmd_args, cwd=ref_tar_md5sum_path.parent, encoding="utf-8", text=True
                )
            except subprocess.CalledProcessError:
                pass
            else:
                output = output.rstrip()
                if output == f"{ref_tar_path.name}: OK":
                    tar_file_confirmed_ok = True

        if not tar_file_confirmed_ok:
            tmp_ref_tar_path = tmp_dir_path / ref_tar_path.name
            tmp_ref_tar_md5sum_path = tmp_dir_path / f"{ref_tar_path.name}.md5sum"

            tar_czf_cmd_args = [
                "tar",
                "czf",
                str(tmp_ref_tar_path),
                "-C",
                str(hmm_library_basedir.parent),
                library_name,
            ]
            subprocess.run(tar_czf_cmd_args, check=True)

            gzip_test_cmd_args = [
                "gzip",
                "--test",
                str(tmp_ref_tar_path),
            ]
            subprocess.run(gzip_test_cmd_args, check=True)

            md5sum_gen_cmd_args = [
                "md5sum",
                tmp_ref_tar_path.name,
            ]
            with open(tmp_ref_tar_md5sum_path, mode="w", encoding="utf-8") as out_file_obj:
                subprocess.run(
                    md5sum_gen_cmd_args, stdout=out_file_obj, cwd=tmp_dir_path, encoding="utf-8", check=True
                )

            shutil.move(tmp_ref_tar_path, ref_tar_path)
            shutil.move(tmp_ref_tar_md5sum_path, ref_tar_md5sum_path)

    prev_compara_dir_path = prev_ftp_dump_root / tar_dir_path
    prev_hmm_tar_file_path = None

    if prev_compara_dir_path.is_dir():
        path_spec = "multi_division_hmm_lib*.tar.gz"
        prev_hmm_tar_file_paths = list(prev_compara_dir_path.glob(path_spec))

        if len(prev_hmm_tar_file_paths) == 1:
            prev_hmm_tar_file_path = prev_hmm_tar_file_paths[0]
        elif len(prev_hmm_tar_file_paths) > 1:
            raise RuntimeError(
                f"path spec {path_spec!r} matches multiple archive"
                f" files in directory {str(prev_compara_dir_path)!r}"
            )

    curr_compara_dir_path = curr_ftp_dump_root / tar_dir_path
    curr_hmm_tar_file_path = curr_compara_dir_path / ref_tar_path.name
    os.makedirs(curr_compara_dir_path, mode=0o775, exist_ok=True)

    if prev_hmm_tar_file_path and (
        ref_tar_path.name == prev_hmm_tar_file_path.name  # pylint: disable=consider-using-in
        # HMM lib files will retain the library name from e114 onwards,
        # so from e115, it should be safe to delete the following line.
        or prev_hmm_tar_file_path.name == "multi_division_hmm_lib.tar.gz"
    ):
        compara_dir_to_root_path = os.path.relpath(curr_ftp_dump_root, start=curr_compara_dir_path)
        curr_to_prev_root_path = Path(os.path.relpath(prev_ftp_pub_root, start=curr_ftp_pub_root))

        new_symlink_target = (
            compara_dir_to_root_path / curr_to_prev_root_path / tar_dir_path / prev_hmm_tar_file_path.name
        )

        if prev_hmm_tar_file_path.is_symlink():
            prev_symlink_target = Path(os.readlink(prev_hmm_tar_file_path))
            if not prev_symlink_target.is_absolute():
                new_symlink_target = Path(os.path.normpath(new_symlink_target.parent / prev_symlink_target))

        with TemporaryDirectory(dir=curr_compara_dir_path, prefix=".symlink_tmp_") as tmp_dir:
            tmp_hmm_tar_file_path = os.path.join(tmp_dir, curr_hmm_tar_file_path.name)
            os.symlink(new_symlink_target, tmp_hmm_tar_file_path)
            shutil.move(tmp_hmm_tar_file_path, curr_hmm_tar_file_path)

    else:
        shutil.copyfile(ref_tar_path, curr_hmm_tar_file_path)
