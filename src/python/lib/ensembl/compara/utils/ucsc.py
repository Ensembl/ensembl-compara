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
"""Utilities for working with UCSC data."""

__all__ = ["load_chrom_sizes_file"]

from pathlib import Path
from typing import Dict, Union


def load_chrom_sizes_file(chrom_sizes_file: Union[Path, str]) -> Dict[str, int]:
    """Load genome sequence sizes from a UCSC chrom sizes file.

    Args:
        chrom_sizes_file: Input chrom sizes file.

    Returns:
        Dictionary mapping genome sequence names to their lengths.
    """
    chrom_sizes = {}
    with open(chrom_sizes_file) as in_file_obj:
        for line in in_file_obj:
            chrom_name, chrom_size = line.rstrip("\n").split("\t")
            chrom_sizes[chrom_name] = int(chrom_size)

    return chrom_sizes
