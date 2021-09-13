#!/usr/bin/env python3
"""This script prepare a file that will be consumed by cactus-prepare. It
reads a given tree and attach the FASTA file paths"""

import argparse
import os
import sys
import re
from datetime import datetime

# check if biopython package is installed
try:
    from Bio import Phylo
except ModuleNotFoundError as error:
    print(error)
    print('Please, run "pip install biopython" to install Biopython module')
    sys.exit(1)


def assemblies_parser(dest, ext):
    """A function to parse the meta information of FASTA files

    Args:
        dest: the location where the FASTA files are localised
        ext: extention of the files expected to be found in `dest`

    Returns:
        A dictionary containing the path, filename, and bool flag for each file.ext in `deset`

    """
    dest = os.path.abspath(dest)

    # sanity check
    ext = re.sub("\\W+|_", "", ext).lower()
    ext = "." + ext

    try:
        filenames = os.listdir(dest)
    except FileNotFoundError as err:
        raise err

    content = {}

    for filename in filenames:
        if filename.endswith(ext):

            key = re.sub("\\W+|_", "", filename).lower()

            # sanity check
            assert key not in content

            content[key] = {
                "path": "{}/{}".format(dest, filename),
                "name": filename.rsplit(ext, 1)[0],
                "used": False,
            }
        else:
            print(
                "filename {} does not end with {}, thus it has been ignored".format(
                    filename, ext
                )
            )

    return content


def tree_parser(filename, tree_format, output):
    """A function to parse the given tree

    Args:
        filename: The path of the file containing the tree
        tree_format: The format of the tree
        output: The path to generate the cactus input file

    Returns:
        A dictionary containing the tree and path (where the Cactus input file will be saved)

    """
    with open(filename, encoding="utf-8", mode="r") as f:

        if output is None:
            output = os.path.dirname(os.path.realpath(f.name))
        else:
            output = os.path.abspath(output)

        name, ext = os.path.splitext(os.path.basename(f.name))
        output += "/{}.processed{}".format(name, ext)
        tree = Phylo.read(f, format=tree_format)

    return {"tree": tree, "path": output}


def create_new_tree(tree_content, assemblies_content, tree_format):
    """Create a Newick tree with sequence names based on the FASTA filenames parsed before

    Args:
        tree_content: The dictionary containing the tree information
        assemblies_content: The dictionary containing the fasta file information
        format: The format of the tree

    Returns:
        A list of filenames containing the FASTA files that have been parsed but not
        included in the given tree

    """

    for leaf in tree_content["tree"].get_terminals():

        name = re.sub("\\W+|_", "", leaf.name).lower()
        for key, fasta in assemblies_content.items():
            if name in key:
                leaf.name = fasta["name"]
                fasta["used"] = True
                break

    # remove labels on non-leaf nodes
    for non_leaf in tree_content["tree"].get_nonterminals():
        non_leaf.confidence = None

    Phylo.write(
        trees=tree_content["tree"],
        file=tree_content["path"],
        format=tree_format,
        format_branch_length="%s",
        branch_length_only=True,
    )

    # sanity check
    filenames_not_used = []
    for fasta in assemblies_content.values():
        if not fasta["used"]:
            print("FASTA file not used in the tree: {}".format(fasta["name"]))
            filenames_not_used.append(fasta)

    return filenames_not_used


def append_fasta_paths(filename, content):
    """Funciton to append text to a given file

    Args:
        filename: The path for the file
        content: The content to be amended in the file

    """
    with open(filename, encoding="utf-8", mode="a") as f:
        for fasta in content.values():
            if fasta["used"]:
                f.write("{} {}\n".format(fasta["name"], fasta["path"]))


def add_header(
    cactus_prepare_filename,
    tree_filename,
    argv,
    qtd_files,
    qtd_terminals,
    unused_filenames,
):
    """Funciton to create a header to the cactus input file

    Args:
        cactus_prepare_filename: The path to generate the cactus input file
        tree_filename: The path of the tree
        argv: The arguments given for this script
        qtd_files: The amount of files parsed
        qtd_terminals: The amount of leaves (terminals) of the tree
        unused_filenames: The list of files that have not been used for sanity-check

    """

    with open(cactus_prepare_filename, encoding="utf-8", mode="r") as f:
        new_content = f.read().replace(":None", "")

    with open(tree_filename, encoding="utf-8", mode="r") as f:
        old_content = f.read()

    with open(cactus_prepare_filename, encoding="utf-8", mode="w+") as f:
        f.write(
            "# File generated On {}\n".format(
                datetime.now().strftime("%d/%m/%Y %H:%M:%S")
            )
        )
        f.write("# by the following command: {}\n".format(" ".join(argv)))
        f.write("#\n")
        f.write("# Original tree:")
        f.write("\n# {}".format(old_content))
        f.write("#\n")
        f.write(
            "# Tree below contains files={} and terminals={}".format(
                qtd_files - len(unused_filenames), qtd_terminals
            )
        )
        f.write("\n# Files not used: ")
        if len(unused_filenames) == 0:
            f.write("None\n")
        else:
            f.write("\n")
            for fasta in unused_filenames:
                f.write("# {} {}\n".format(fasta["name"], fasta["path"]))
        f.write("#\n")
        f.write(new_content)


if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--assemblies_dir",
        type=str,
        required=True,
        help="Directory where FASTA files are localised",
    )

    parser.add_argument(
        "--extension",
        type=str,
        required=False,
        default=".fa",
        help="The expected extension of the files containing the assemblies",
    )

    parser.add_argument(
        "--tree", type=str, required=True, help="File that describes the tree"
    )

    parser.add_argument(
        "--format",
        type=str,
        required=False,
        default="newick",
        help="Format of the tree",
    )

    parser.add_argument(
        "--output_dir",
        type=str,
        default=None,
        help="The location where the output file (aka cactus input file) will be stored",
    )

    args = parser.parse_args()

    # parse the fasta files
    assemblies_data = assemblies_parser(dest=args.assemblies_dir, ext=args.extension)

    # parse the tree and create the cactus input file
    tree_data = tree_parser(
        filename=args.tree, tree_format=args.format, output=args.output_dir
    )

    # sanity check
    unused_filenames = create_new_tree(tree_data, assemblies_data, args.format)

    # append FASTA locations to the cactus input file
    append_fasta_paths(tree_data["path"], assemblies_data)

    # add a header as comments to the cactus input file
    add_header(
        cactus_prepare_filename=tree_data["path"],
        tree_filename=args.tree,
        argv=sys.argv,
        qtd_files=len(assemblies_data),
        qtd_terminals=len(tree_data["tree"].get_terminals()),
        unused_filenames=unused_filenames,
    )
