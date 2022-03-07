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

"""Convert each block of a MAF alignment to a FASTA file.

Examples::
    python maf_to_fasta.py --genomes-file genomes.txt input.maf output_dir/

"""

from argparse import ArgumentParser
import json
import os
from pathlib import Path
import re
from typing import Dict, Pattern, Sequence, Tuple, Union

from Bio.AlignIO.MafIO import MafIterator
from Bio import SeqIO
from Bio.SeqRecord import SeqRecord


def compile_maf_src_regex(genome_names: Sequence[str]) -> Pattern[str]:
    """Make a MAF src field regex for the given genome names.

    In the UCSC multiple alignment format (MAF), the src field can be of the form '<genome>.<seqid>',
    which is useful for storing both the genome and sequence name; these can then be extracted by taking
    the substrings before and after the dot character ('.'), respectively. However, this cannot be done
    unambiguously if there is a dot in either the genome or sequence name. Taking the names of genomes
    known to be in a MAF file, this function creates a string Pattern object that can be used to extract
    the genome and sequence names from a MAF src field of the form '<genome>.<seqid>'.

    Args:
        genome_names: The genome names expected to be in the input MAF file.

    Returns:
        Compiled string Pattern object.

    Raises:
        ValueError: If any of the input genome names is a prefix of any other genome name
            and that prefix is followed by a dot ('.') in the longer genome name, the longer
            genome name can never match unambiguously, and this function cannot be used to
            extract the genome and sequence names. For example, genomes 'genomeA' and
            'genomeA.1' would both match src field 'genomeA.1.1'.

    Example::
        >>> maf_src_regex = compile_maf_src_regex(['genomeA.1', 'genomeB.1'])
        >>> match = maf_src_regex.match('genomeA.1.1')
        >>> match['genome']
        'genomeA.1'
        >>> match['seqid']
        '1'

    """
    for genome_name in genome_names:
        dot_regex = re.compile('[.]')
        for match in dot_regex.finditer(genome_name):
            prefix = genome_name[:match.start()]
            if prefix in genome_names:
                raise ValueError(f"cannot create a MAF src regex — genome name '{prefix}'"
                                 f" is a prefix of '{genome_name}'")
    genome_patt = '|'.join(map(re.escape, genome_names))
    maf_src_patt = f'^(?P<genome>{genome_patt})[.](?P<seqid>.+)$'
    return re.compile(maf_src_patt)


def main(maf_file: Union[Path, str], output_dir: Union[Path, str],
         genomes_file: Union[Path, str] = None) -> None:
    """Convert each block of a MAF alignment to a FASTA file.

    Args:
        maf_file: Input MAF file with alignment blocks. The src fields of
            this MAF file should be of the form '<genome>.<seqid>'.
        output_dir: Output directory under which FASTA files will be created.
        genomes_file: File listing the genomes in the input MAF file, one per line. This is used
            to compile a regex that splits MAF src fields of the form '<genome>.<seqid>'
            into their component parts. If any of the genomes or their sequences in the
            MAF file contains a dot ('.'), this is required.

    Raises:
        ValueError: If a MAF src field cannot be parsed.

    """

    if genomes_file is not None:
        with open(genomes_file) as f:
            genome_names = [line.rstrip() for line in f]
        maf_src_regex = compile_maf_src_regex(genome_names)

    out_dir_path = Path(output_dir)

    maf_src_map: Dict[str, Tuple[str, str]] = {}
    with open(maf_file) as in_f:
        for idx, msa in enumerate(MafIterator(in_f)):
            idx_dir_path = out_dir_path / map_uint_to_path(idx)
            os.makedirs(idx_dir_path, exist_ok=True)

            ga_recs = []
            fasta_file_path = idx_dir_path / f'{idx}.fa'
            with open(fasta_file_path, 'w') as out_f:
                for rec in msa:
                    maf_src = rec.id

                    try:
                        genome_name, dnafrag_name = maf_src_map[maf_src]
                    except KeyError:
                        try:
                            genome_name, dnafrag_name = maf_src.split('.')
                            maf_src_map[maf_src] = (genome_name, dnafrag_name)
                        except ValueError as exc:
                            if genomes_file is None:
                                raise ValueError(
                                    "MAF src field parse failed due to multiple dot separators"
                                    " — please set genome names with the '--genomes-file' parameter"
                                ) from exc

                            match = maf_src_regex.match(maf_src)
                            try:
                                genome_name = match['genome']  # type: ignore
                                dnafrag_name = match['seqid']  # type: ignore
                            except TypeError as exc:
                                raise ValueError(
                                    "MAF src regex failed to parse MAF src field: '{maf_src}'") from exc

                            maf_src_map[maf_src] = (genome_name, dnafrag_name)

                    maf_start = rec.annotations['start']
                    maf_size = rec.annotations['size']
                    maf_end = maf_start + maf_size
                    dnafrag_strand = rec.annotations['strand']

                    if dnafrag_strand == 1:
                        dnafrag_start = maf_start + 1
                        dnafrag_end = maf_end
                    else:
                        maf_src_size = rec.annotations['srcSize']
                        dnafrag_start = maf_src_size - maf_end + 1
                        dnafrag_end = maf_src_size - maf_start

                    fasta_id = f'{genome_name}:{dnafrag_name}:{dnafrag_start}:{dnafrag_end}'
                    fasta_rec = SeqRecord(rec.seq, id=fasta_id, name='', description='')
                    SeqIO.write([fasta_rec], out_f, 'fasta')

                    ga_recs.append({
                        'genome_name': genome_name,
                        'dnafrag_name': dnafrag_name,
                        'dnafrag_start': dnafrag_start,
                        'dnafrag_end': dnafrag_end,
                        'dnafrag_strand': dnafrag_strand
                    })

            json_file_path = idx_dir_path / f'{idx}.json'
            with open(json_file_path, 'w') as f:
                json.dump(ga_recs, f)


def map_uint_to_path(non_negative_integer: int) -> Path:
    """Compose a multilevel directory path from a non-negative integer.

    This function is based on the EnsEMBL Hive Perl function ``dir_revhash``.
    Like the original Perl function, this function maps an input value to a
    multilevel directory path (without making any changes to the file system).
    Unlike ``dir_revhash``, this function only accepts a non-negative integer.

    Given an input non-negative integer (e.g. 1234), this is converted to a
    string (e.g. '1234'), the first digit is dropped (e.g. '234'), the string
    is reversed (e.g. '432'), and a Path object is returned in which each of
    the remaining digits is a path component (e.g. 'Path(4/3/2)').

    Appending this generated path to a base directory enables the creation of
    a directory where files associated with the specified integer can be created
    and accessed. Note that because the first digit is dropped, the created
    directory may contain files corresponding to up to 10 integers, so files
    associated with a specific integer should be named in a way that allows them
    to be distinguished from files relevant to other integers (e.g. '1234.tsv').

    Args:
        non_negative_integer: A non-negative integer.

    Returns:
        The composed pathlib.Path object.

    Raises:
        TypeError: If the argument ``non_negative_integer`` is not of integer type,
            or cannot be converted to an integer string.
        ValueError: If the argument ``non_negative_integer`` is a negative integer.

    """
    try:
        integer_string = format(non_negative_integer, 'd')
    except (TypeError, ValueError) as exc:
        patt = re.compile("^(unsupported format string passed to [^.]+[.]__format__"
                          "|Unknown format code 'd' for object of type '[^']+')$")

        if patt.match(str(exc)):
            arg_type_name = type(non_negative_integer).__name__
            msg = f"cannot compose integer-derived path for object of type '{arg_type_name}'"
            raise TypeError(msg) from exc

        raise exc

    if non_negative_integer < 0:
        raise ValueError(
            f'cannot compose integer-derived path for negative integer: {non_negative_integer}')

    return Path(*reversed(integer_string[1:]))


if __name__ == '__main__':

    parser = ArgumentParser(description='Convert each block of a MAF alignment to a FASTA file.')
    parser.add_argument('maf_file', metavar='PATH',
                        help="Input MAF file with alignment blocks. The src fields of"
                             "this MAF file should be of the form '<genome>.<seqid>'.")
    parser.add_argument('output_dir', metavar='PATH',
                        help='Output directory under which FASTA files will be created.')
    parser.add_argument('--genomes-file', metavar='PATH',
                        help="File listing the genomes in the input MAF file, one per line. This is used"
                             " to compile a regex that splits MAF src fields of the form '<genome>.<seqid>'"
                             " into their component parts. If any of the genomes or their sequences in the"
                             " MAF file contains a dot ('.'), this is required.")

    args = parser.parse_args()
    main(**vars(args))
