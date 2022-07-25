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
"""Unit testing of `orthology_benchmark.py` script.

Typical usage example::

    $ pytest test_orthology_benchmark.py

"""

from contextlib import nullcontext as does_not_raise
from importlib.abc import Loader
from importlib.machinery import ModuleSpec
from importlib.util import module_from_spec, spec_from_file_location
import os
from pathlib import Path
import re
import sys
from typing import ContextManager, Dict, List, Tuple

import pandas
import sqlalchemy

import pytest
from pytest import FixtureRequest, raises, warns  # type: ignore

from ensembl.compara.filesys import file_cmp


script_path = Path(__file__).parents[3] / "scripts" / "pipeline" / "orthology_benchmark.py"
script_name = script_path.stem
script_spec = spec_from_file_location(script_name, script_path)

if not isinstance(script_spec, ModuleSpec):
    raise ImportError(f"ModuleSpec not created for module file '{script_path}'")
if not isinstance(script_spec.loader, Loader):
    raise ImportError(f"no loader found for module file '{script_path}'")

orthology_benchmark_module = module_from_spec(script_spec)
sys.modules[script_name] = orthology_benchmark_module
script_spec.loader.exec_module(orthology_benchmark_module)

# pylint: disable=import-error,wrong-import-order,wrong-import-position

import orthology_benchmark  # type: ignore

# pylint: enable=import-error,wrong-import-order,wrong-import-position


@pytest.mark.parametrize(
    "multi_dbs",
    [
        [{'src': 'core/gallus_gallus_core_99_6'}, {'src': 'core/homo_sapiens_core_99_38'}]
    ],
    indirect=True
)
class TestDumpGenomes:
    """Tests :func:`orthology_benchmark.dump_genomes()` function.

    Attributes:
        core_dbs: A set of test core databases.
        host: Host of the test database server.
        port: Port of the test database server.
        username: Username to access the test `host:port`

    """

    core_dbs = {}  # type: Dict
    host = None  # type: str
    port = None  # type: int
    username = None  # type: str

    # autouse=True makes this fixture be executed before any test_* method of this class, and scope='class' to
    # execute it only once per class parametrization
    @pytest.fixture(scope='class', autouse=True)
    def setup(self, request: FixtureRequest, multi_dbs: Dict) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            request: Access to the requesting test context.
            multi_dbs: Dictionary of unit test databases (fixture).

        """
        type(self).core_dbs = multi_dbs
        server_url = sqlalchemy.engine.url.make_url(request.config.getoption('server'))
        type(self).host = server_url.host
        type(self).port = server_url.port
        type(self).username = "ensro" if server_url.username == "ensadmin" else server_url.username

    @pytest.mark.skipif(os.environ['USER'] == 'travis',
                        reason="The test requires both Perl and Python which is not supported by Travis.")
    @pytest.mark.parametrize(
        "core_list, species_set_name, id_type, expectation",
        [
            (
                [f"{os.environ['USER']}_gallus_gallus_core_99_6",
                 f"{os.environ['USER']}_homo_sapiens_core_99_38"],
                "default", "protein", does_not_raise()
            ),
            ([], "test", "gene", raises(ValueError, match=r"No cores to dump."))
        ]
    )
    def test_dump_genomes(self, core_list: List[str], species_set_name: str,
                          tmp_dir: Path, id_type: str, expectation: ContextManager) -> None:
        """Tests :func:`orthology_benchmark.dump_genomes()` when server connection can be established.

        Args:
            species_list: A list of species (genome names).
            species_set_name: Species set (collection) name.
            tmp_dir: Unit test temp directory (fixture).
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            orthology_benchmark.dump_genomes(core_list, species_set_name, self.host, self.port, tmp_dir,
                                             id_type)

            out_files = tmp_dir / species_set_name
            # pylint: disable-next=no-member
            exp_out = pytest.files_dir / "orth_benchmark"  # type: ignore[attr-defined, operator]
            for db_name, unittest_db in self.core_dbs.items():
                assert file_cmp(out_files / f"{unittest_db.dbc.db_name}.fasta", exp_out / f"{db_name}.fasta")


    def test_dump_genomes_fake_output_path(self) -> None:
        """Tests :func:`orthology_benchmark.dump_genomes()` with fake output path."""
        with raises(OSError, match=r"Failed to create '/compara/default' directory."):
            orthology_benchmark.dump_genomes(["mus_musculus", "naja_naja"], "default",
                                             self.host, self.port, "/compara", "protein")


def test_dump_genomes_fake_connection(tmp_dir: Path) -> None:
    """Tests :func:`orthology_benchmark.dump_genomes()` with fake server details.

    Args:
        tmp_dir: Unit test temp directory (fixture).

    """
    with raises(RuntimeError):
        orthology_benchmark.dump_genomes(["mus_musculus", "naja_naja"], "fake", "fake-host", 65536,
                                         tmp_dir, "protein")


@pytest.mark.parametrize(
    "core_names, exp_output, expectation",
    [
        (["mus_musculus_core_105_1", "mus_musculus_core_52_105_3", "mus_musculus_core_104_4"],
         "mus_musculus_core_52_105_3", does_not_raise()),
        ([], None, raises(ValueError,
                          match=r"Empty list of core databases. Cannot determine the latest one."))
    ]
)
def test_find_latest_core(core_names: List[str], exp_output: str, expectation: ContextManager) -> None:
    """Tests :func:`orthology_benchmark.find_latest_core()` function.

    Args:
        core_names: A list of core database names.
        exp_output: Expected return value of the function.
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
            exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    with expectation:
        assert orthology_benchmark.find_latest_core(core_names) == exp_output


@pytest.mark.parametrize(
    "multi_dbs",
    [
        [{'src': 'core/danio_rerio_core_105_11'}, {'src': 'core/mus_musculus_cbaj_core_107_1'},
         {'src': 'core/mus_musculus_core_106_39'}]
    ],
    indirect=True
)
class TestGetCoreNames:
    """Tests :func:`orthology_benchmark.get_core_names()` function.

    Attributes:
        core_dbs: A set of test core databases.
        host: Host of the test database server.
        port: Port of the test database server.
        username: Username to access the test `host:port`

    """

    core_dbs = {}  # type: Dict
    host = None  # type: str
    port = None  # type: int
    username = None  # type: str

    # autouse=True makes this fixture be executed before any test_* method of this class, and scope='class' to
    # execute it only once per class parametrization
    @pytest.fixture(scope='class', autouse=True)
    def setup(self, request: FixtureRequest, multi_dbs: Dict) -> None:
        """Loads the required fixtures and values as class attributes.

        Args:
            request: Access to the requesting test context.
            multi_dbs: Dictionary of unit test databases (fixture).

        """
        type(self).core_dbs = multi_dbs
        server_url = sqlalchemy.engine.url.make_url(request.config.getoption('server'))
        type(self).host = server_url.host
        type(self).port = server_url.port
        type(self).username = "ensro" if server_url.username == "ensadmin" else server_url.username

    @pytest.mark.parametrize(
        "species_names, exp_output, expectation",
        [
            (["danio_rerio", "mus_musculus", "zea_mays"],
             {"danio_rerio": os.environ['USER'] + "_danio_rerio_core_105_11",
              "mus_musculus": os.environ['USER'] + "_mus_musculus_core_106_39"},
             does_not_raise()),
            ([], None, raises(ValueError,
                              match=r"Empty list of species names. Cannot search for core databases."))
        ]
    )
    def test_get_core_names(self, species_names: List[str], exp_output: Dict[str, str],
                            expectation: ContextManager) -> None:
        """Tests :func:`orthology_benchmark.get_core_names()` when server connection can be established.

        Args:
            species_names: Species (genome) names.
            exp_output: Expected return value of the function.
            expectation: Context manager for the expected exception, i.e. the test will only pass if that
                exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

        """
        with expectation:
            assert orthology_benchmark.get_core_names(species_names, self.host, self.port,
                                                      self.username) == exp_output

def test_get_core_names_fake_connection() -> None:
    """Tests :func:`orthology_benchmark.get_core_names()` with fake server details."""
    with raises(sqlalchemy.exc.OperationalError):
        orthology_benchmark.get_core_names(["danio_rerio", "mus_musculus"], "fake-host", 65536, "compara")


@pytest.mark.parametrize(
    "core_name, expectation",
    [
        ("juglans_regia_core_51_104_1", does_not_raise()),
        ("ensembl_compara_core_53_106_30", warns(UserWarning,
                                                 match=r"GTF file for 'ensembl_compara_core_53_106_30' "
                                                       r"not found."))
    ]
)
def test_get_gtf_file(core_name: str, tmp_dir: Path, expectation: ContextManager) -> None:
    """Tests :func:`orthology_benchmark.get_gtf_file()` function.

    Args:
        core_name: Core db name.
        tmp_dir: Unit test temp directory (fixture).
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
            exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    # pylint: disable-next=no-member
    test_source_dir = pytest.files_dir / "orth_benchmark"  # type: ignore[attr-defined, operator]
    with expectation:
        orthology_benchmark.get_gtf_file(core_name, test_source_dir, tmp_dir)

    exp_out = test_source_dir / "release-51" / "plants" / "gtf" / "juglans_regia" / \
              "Juglans_regia.Walnut_2.0.51.gtf.gz"
    assert file_cmp( tmp_dir / "Juglans_regia.Walnut_2.0.51.gtf.gz", exp_out)


@pytest.mark.parametrize(
    "core_names, expectation",
    [
        (["juglans_regia_core_51_104_1", "anopheles_albimanus_core_51_104_2"], does_not_raise()),
        ([], raises(ValueError, match=r"Empty list of core db names. Cannot search for GTF files."))
    ]
)
def test_prepare_gtf_files(core_names: str, tmp_dir: Path, expectation: ContextManager) -> None:
    """Tests :func:`orthology_benchmark.prepare_gtf_files()` function.

    Args:
        core_names: Core db names.
        tmp_dir: Unit test temp directory (fixture).
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
            exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    # pylint: disable-next=no-member
    test_source_dir = pytest.files_dir / "orth_benchmark"  # type: ignore[attr-defined, operator]
    with expectation:
        orthology_benchmark.prepare_gtf_files(core_names, test_source_dir, tmp_dir)

        rel_dir = test_source_dir / "release-51"
        exp_out1 = rel_dir / "plants" / "gtf" / "juglans_regia" / "Juglans_regia.Walnut_2.0.51.gtf"
        exp_out2 = rel_dir / "metazoa" / "gtf" / "anopheles_albimanus" / "Anopheles_albimanus.AalbS2.51.gtf"
        assert file_cmp( tmp_dir / "Juglans_regia.Walnut_2.0.51.gtf", exp_out1)
        assert file_cmp( tmp_dir / "Anopheles_albimanus.AalbS2.51.gtf", exp_out2)


def test_extract_orthologs() -> None:
    """Tests :func:`orthology_benchmark.extract_orthologs()` function.
    """
    # pylint: disable-next=no-member
    test_files_dir = pytest.files_dir / "orth_benchmark" # type: ignore[attr-defined, operator]
    orthofinder_res = test_files_dir  / "OrthoFinder" / "Results_Mar03"
    assert orthology_benchmark.extract_orthologs(
        orthofinder_res, "gallus_gallus_core_106_6", "homo_sapiens_core_106_38"
    ) == [("ENSGALG00000030005", "ENSG00000147255")]


@pytest.mark.parametrize(
    "species_key, exp_output",
    [
        ("homo_sapiens_core_106_38",
         [("ENSG00000163565", "ENSG00000163568"), ("ENSG00000186081", "ENSG00000135480"),
          ("ENSG00000170465", "ENSG00000135480"), ("ENSG00000185479", "ENSG00000135480"),
          ("ENSG00000205420", "ENSG00000135480")]),
        ("gallus_gallus_core_106_6",
         [("ENSGALG00000032672", "ENSGALG00000035972"), ("ENSGALG00000032672", "ENSGALG00000030629"),
          ("ENSGALG00000032672", "ENSGALG00000038579"), ("ENSGALG00000032672", "ENSGALG00000033381"),
          ("ENSGALG00000032672", "ENSGALG00000043689"), ("ENSGALG00000032672", "ENSGALG00000034868"),
          ("ENSGALG00000035972", "ENSGALG00000038579"), ("ENSGALG00000035972", "ENSGALG00000033381"),
          ("ENSGALG00000035972", "ENSGALG00000043689"), ("ENSGALG00000035972", "ENSGALG00000034868"),
          ("ENSGALG00000030629", "ENSGALG00000038579"), ("ENSGALG00000030629", "ENSGALG00000033381"),
          ("ENSGALG00000030629", "ENSGALG00000043689"), ("ENSGALG00000030629", "ENSGALG00000034868"),
          ("ENSGALG00000035972", "ENSGALG00000030629")]),
        ("ensembl_compara", [])
    ]
)
def test_extract_paralogs(species_key: str, exp_output: List[Tuple[str, str]]) -> None:
    """Tests :func:`orthology_benchmark.extract_paralogs()` function.

    Args:
        species_key: OrthoFinder identificator of the species of interest.
        exp_output: Expected return value of the function.

    """
    # pylint: disable-next=no-member
    test_files_dir = pytest.files_dir / "orth_benchmark"  # type: ignore[attr-defined, operator]
    orthofinder_res = test_files_dir / "OrthoFinder" / "Results_Mar03"
    assert orthology_benchmark.extract_paralogs(orthofinder_res, species_key) == exp_output


@pytest.mark.parametrize(
    "species_name, exp_data, expectation",
    [
        ("anopheles_albimanus",
         [["2R", "AALB007248", 16547908, "+"], ["2R", "AALB008253", 30120952, "-"],
          ["2R", "AALB014269", 44548737, "+"], ["3L", "AALB004554", 11249104, "-"]],
         does_not_raise()),
        ("ensembl_compara", None, raises(FileNotFoundError,
                                         match=r"GTF file for 'ensembl_compara' not found."))
    ]
)
def test_read_in_gtf(species_name: str, exp_data: Tuple[str, str, int, str], expectation: ContextManager)\
        -> None:
    """Tests :func:`orthology_benchmark.read_in_gtf()` function.

    Args:
        species_name: Species (genome) name.
        exp_data: Expected values in return data frame of the function.
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
            exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    # pylint: disable-next=no-member
    test_source_dir = pytest.files_dir / "orth_benchmark"  # type: ignore[attr-defined, operator]
    test_gtf_dir = test_source_dir / "release-51" / "metazoa" / "gtf" / "anopheles_albimanus"

    with expectation:
        out_df = orthology_benchmark.read_in_gtf(species_name, test_gtf_dir)
        exp_df = pandas.DataFrame(exp_data, columns=["seqname", "gene_id", "start", "strand"])
        pandas.testing.assert_frame_equal(out_df, exp_df)

@pytest.mark.parametrize(
    "test_genes, test_paralogs, exp_genes, exp_paralogs",
    [
        ([["PYXB01142696.1", "ENSOSUG003240", 12, "-"], ["PYXB01142552.1", "ENSOSUG003223", 38, "-"],
          ["ML997581.1", "ENSOSUG000105", 84807, "+"], ["ML997581.1", "ENSOSUG000063", 55600, "+"],
          ["ML997581.1", "ENSOSUG000020", 34779, "+"], ["ML997581.1", "ENSOSUG000012", 25596, "+"],
          ["ML997581.1", "ENSOSUG000006", 6188, "+"], ["ML997581.1", "ENSOSUG000008", 15846, "+"],
          ["PYXB01141513.1", "ENSOSUG003211", 2, "-"]],
         [("ENSOSUG000006", "ENSOSUG000105"), ("ENSOSUG000008", "ENSOSUG000012"),
          ("ENSOSUG000020", "ENSOSUG000008"), ("ENSOSUG000020", "ENSOSUG000012"),
          ("ENSOSUG000020", "ENSOSUG000063"), ("ENSOSUG000105", "ENSOSUG003211")],
         [["ML997581.1", "ENSOSUG000006", 6188, "+"], ["ML997581.1", "ENSOSUG000008", 15846, "+"],
          ["ML997581.1", "ENSOSUG000105", 84807, "+"], ["PYXB01141513.1", "ENSOSUG003211", 2, "-"],
          ["PYXB01142552.1", "ENSOSUG003223", 38, "-"], ["PYXB01142696.1", "ENSOSUG003240", 12, "-"]],
         {"ENSOSUG000012": "ENSOSUG000008", "ENSOSUG000020": "ENSOSUG000012",
          "ENSOSUG000063": "ENSOSUG000020"}),
        ([["ML997581.1", "ENSOSUG000006", 6188, "+"], ["ML997581.1", "ENSOSUG000008", 15846, "+"],
          ["ML997581.1", "ENSOSUG000012", 25596, "+"]],
         [("ENSOSUG000008", "ENSOSUG000012")],
         [["ML997581.1", "ENSOSUG000006", 6188, "+"], ["ML997581.1", "ENSOSUG000008", 15846, "+"]],
         {"ENSOSUG000012": "ENSOSUG000008"}),
        ([["ML997581.1", "ENSOSUG000006", 6188, "+"], ["ML997581.1", "ENSOSUG000008", 15846, "+"],
          ["ML997581.1", "ENSOSUG000012", 25596, "+"], ["PYXB01141513.1", "ENSOSUG003211", 2, "-"]],
         [("ENSOSUG000012", "ENSOSUG003211")],
         [["ML997581.1", "ENSOSUG000006", 6188, "+"], ["ML997581.1", "ENSOSUG000008", 15846, "+"],
          ["ML997581.1", "ENSOSUG000012", 25596, "+"], ["PYXB01141513.1", "ENSOSUG003211", 2, "-"]],
         {}),
        ([["ML997581.1", "ENSOSUG000006", 6188, "+"], ["ML997581.1", "ENSOSUG000008", 15846, "+"],
          ["ML997581.1", "ENSOSUG000012", 25596, "+"], ["PYXB01141513.1", "ENSOSUG003211", 2, "-"]],
         [("ENSOSUG000006", "ENSOSUG000012")],
         [["ML997581.1", "ENSOSUG000006", 6188, "+"], ["ML997581.1", "ENSOSUG000008", 15846, "+"],
           ["ML997581.1", "ENSOSUG000012", 25596, "+"], ["PYXB01141513.1", "ENSOSUG003211", 2, "-"]],
          {}),
    ]
)
def test_collapse_tandem_paralogs_w_keep(test_genes: Tuple[str, str, int, str],
                                         test_paralogs: List[Tuple[str, str]],
                                         exp_genes: Tuple[str, str, int, str], exp_paralogs: Dict[str, str])\
        -> None:
    """Tests :func:`orthology_benchmark.collapse_tandem_paralogs()` function when it returns an optional
    dictionary.

    Args:
        test_genes: A list of lists containing information about test genes (GTF "seqname", "gene_id",
            "start", "strand").
        test_paralogs: A list of test putative paralogous pairs.
        exp_genes: A list of lists containing information about genes in the expected output data frame
            (GTF "seqname", "gene_id", "start", "strand").
        exp_paralogs: A list of putative paralogous pairs in the expected output.

    """
    test_df = pandas.DataFrame(test_genes, columns=["seqname", "gene_id", "start", "strand"])
    exp_df = pandas.DataFrame(exp_genes, columns=["seqname", "gene_id", "start", "strand"])
    out_df, tandem_paralogs = orthology_benchmark.collapse_tandem_paralogs(test_df, test_paralogs, True)
    pandas.testing.assert_frame_equal(out_df, exp_df)
    assert tandem_paralogs == exp_paralogs


def test_collapse_tandem_paralogs_wo_keep() -> None:
    """Tests :func:`orthology_benchmark.collapse_tandem_paralogs()` function when it does not return an
    optional dictionary.
    """
    test_genes = [["ML997581.1", "ENSOSUG000006", 6188, "+"], ["ML997581.1", "ENSOSUG000008", 15846, "+"],
                  ["ML997581.1", "ENSOSUG000012", 25596, "+"]]
    test_df = pandas.DataFrame(test_genes, columns=["seqname", "gene_id", "start", "strand"])
    test_paralogs = [("ENSOSUG000008", "ENSOSUG000012")]
    exp_genes = [["ML997581.1", "ENSOSUG000006", 6188, "+"], ["ML997581.1", "ENSOSUG000008", 15846, "+"]]
    exp_df = pandas.DataFrame(exp_genes, columns=["seqname", "gene_id", "start", "strand"])
    out_df = orthology_benchmark.collapse_tandem_paralogs(test_df, test_paralogs, False)
    pandas.testing.assert_frame_equal(out_df, exp_df)


@pytest.mark.parametrize(
    "gene, n, exp_genes, expectation",
    [
        ("ENSOSUG000012", 4, [["ML997581.1", "ENSOSUG000006", 6188, "+"],
                              ["ML997581.1", "ENSOSUG000008", 15846, "+"],
                              ["ML997581.1", "ENSOSUG000012", 25596, "+"],
                              ["ML997581.1", "ENSOSUG000020", 34779, "+"],
                              ["ML997581.1", "ENSOSUG000063", 55600, "+"],
                              ["ML997581.1", "ENSOSUG000105", 84807, "+"]], does_not_raise()),
        ("ENSOSUG000006", 1, [["ML997581.1", "ENSOSUG000006", 6188, "+"],
                              ["ML997581.1", "ENSOSUG000008", 15846, "+"]], does_not_raise()),
        ("ENSOSUG000105", 1, [["ML997581.1", "ENSOSUG000063", 55600, "+"],
                              ["ML997581.1", "ENSOSUG000105", 84807, "+"]], does_not_raise()),
        ("ENSOSUG003240", 2, [["PYXB01142696.1", "ENSOSUG003240", 12, "-"]], does_not_raise()),
        ("ensembl_compara", 2, None, raises(ValueError, match=r"Gene 'ensembl_compara' not found."))
    ]
)
def test_get_neighbours(gene: str, n: int, exp_genes: List[Tuple[str, str, float]],
                        expectation: ContextManager) -> None:
    """Tests :func:`orthology_benchmark.get_neighbours()` function.

    Args:
        gene: `gene_id` of interest.
        n: Radius of the neighbourhood.
        exp_genes: Expected values in return data frame of the function.
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
            exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    test_data = [["ML997581.1", "ENSOSUG000012", 25596, "+"], ["PYXB01142696.1", "ENSOSUG003240", 12, "-"],
                 ["ML997581.1", "ENSOSUG000020", 34779, "+"], ["ML997581.1", "ENSOSUG000006", 6188, "+"],
                 ["ML997581.1", "ENSOSUG000008", 15846, "+"], ["ML997581.1", "ENSOSUG000063", 55600, "+"],
                 ["ML997581.1", "ENSOSUG000105", 84807, "+"], ["PYXB01141513.1", "ENSOSUG003211", 2, "-"],
                 ["PYXB01142552.1", "ENSOSUG003223", 38, "-"]]
    test_df = pandas.DataFrame(test_data, columns=["seqname", "gene_id", "start", "strand"])
    with expectation:
        out_df = orthology_benchmark.get_neighbours(gene, test_df, n)
        exp_df = pandas.DataFrame(exp_genes, columns=["seqname", "gene_id", "start", "strand"])
        pandas.testing.assert_frame_equal(out_df, exp_df)


@pytest.mark.parametrize(
    "neighbours, columns, expectation",
    [
        ([["6", "61", 1, "-"], ["6", "62", 101, "+"]], ["seqname", "gene_id", "start", "strand"],
         does_not_raise()),
        # Missing `gene_id`
        ([["6", 1, "-"], ["6", 101, "+"]], ["seqname", "start", "strand"],
         raises(ValueError, match=r"Neighbourhood is missing at least one of the following columns: "
                                  r"gene_id, strand.")),
        # Missing `strand`
        ([["6", "61", 1], ["6", "62", 101]], ["seqname", "gene_id", "start"],
         raises(ValueError, match=r"Neighbourhood is missing at least one of the following columns: "
                                  r"gene_id, strand.")),
        # Missing `gene_id` and `strand`
        ([["6", 1], ["6", 101]], ["seqname", "start"],
         raises(ValueError, match=r"Neighbourhood is missing at least one of the following columns: "
                                  r"gene_id, strand.")),
        # Corrupted strand
        ([["6", "61", 1, "1"], ["6", "62", 101, "+"]], ["seqname", "gene_id", "start", "strand"],
         raises(ValueError, match=re.escape("The strand of gene '61' is neither + nor -."))),
        ([["6", "61", 1, "-"], ["6", "62", 101, ""]], ["seqname", "gene_id", "start", "strand"],
         raises(ValueError, match=re.escape("The strand of gene '62' is neither + nor -.")))
    ]
)
def test_check_neighbourhood_valid_for_goc(neighbours: List[Tuple], columns: List[str],
                                           expectation: ContextManager) -> None:
    """Tests :func:`orthology_benchmark.check_neighbourhood_valid_for_goc()` function.

    Args:
        neighbours: A list of lists containing information from a GTF file. It might have values for e.g.
            "seqname", "gene_id", "start", "strand".
        columns: Column names for `neighbourhood` data frame.
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
            exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    with expectation:
        neighbourhood = pandas.DataFrame(neighbours, columns=columns)
        assert orthology_benchmark.check_neighbourhood_valid_for_goc(neighbourhood) is None


@pytest.mark.parametrize(
    "gene1, gene2, neighbours1, neighbours2, n, exp_out, expectation",
    [
        # Gene with no neighbours
        ("11", "35",
         [["1", "11", 1, "+"]],
         [["3", "32", 101, "+"], ["3", "33", 201, "+"], ["3", "34", 301, "+"], ["3", "35", 401, "+"],
          ["3", "36", 501, "+"], ["3", "37", 601, "+"], ["3", "38", 701, "+"]],
         2, 0, does_not_raise()),
        # Gene with no neighbours on one side
        ("21", "35",
         [["2", "21", 1, "+"], ["2", "22", 101, "+"], ["2", "23", 201, "+"]],
         [["3", "32", 101, "+"], ["3", "33", 201, "+"], ["3", "34", 301, "+"], ["3", "35", 401, "+"],
          ["3", "36", 501, "+"], ["3", "37", 601, "+"], ["3", "38", 701, "+"]],
         2, 50, does_not_raise()),
        # Gene with one neighbour with multiple orthologous matches ("23" - "31", "23" - "38") (and a
        # collapsed paralogous neighbour ("26"))
        ("25", "33",
         [["2", "23", 201, "+"], ["2", "24", 301, "+"], ["2", "25", 401, "+"], ["2", "27", 601, "+"],
          ["2", "28", 701, "+"]],
         [["3", "31", 1, "+"], ["3", "32", 101, "+"], ["3", "33", 201, "+"], ["3", "34", 301, "+"],
          ["3", "35", 401, "+"], ["3", "36", 501, "+"], ["3", "37", 601, "+"], ["3", "38", 701, "+"],
          ["3", "39", 801, "+"]],
         2, 100, does_not_raise()),
        # All neighbours have an orthologous match and corresponding strands are in agreement
        ("24", "32",
         [["2", "23", 201, "+"], ["2", "24", 301, "+"], ["2", "25", 401, "+"]],
         [["3", "31", 1, "+"], ["3", "32", 101, "+"], ["3", "33", 201, "+"]],
         1, 100, does_not_raise()),
        # Genes of interest on the opposite strands and all neighbours have an orthologous match on the
        # opposite strand
        ("42", "62",
         [["4", "41", 1, "-"], ["4", "42", 101, "-"], ["4", "43", 201, "+"]],
         [["6", "61", 1, "-"], ["6", "62", 101, "+"], ["6", "63", 201, "+"]],
         1, 100, does_not_raise()),
        # Genes of interest on the opposite strands and neighbours have an orthologous match on the same
        # strand
        ("45", "52",
         [["4", "43", 201, "+"], ["4", "44", 301, "+"], ["4", "45", 401, "+"], ["4", "46", 501, "-"],
          ["4", "47", 601, "+"]],
         [["5", "51", 1, "-"], ["5", "52", 101, "-"], ["5", "53", 201, "-"], ["5", "54", 301, "+"]],
         2, 25, does_not_raise()),
        # Orthologous matches don't appear sequentially among the `neighbours2` (and a collapsed paralogous
        # neighbour ("26"))
        ("36", "22",
         [["3", "34", 301, "+"], ["3", "35", 401, "+"], ["3", "36", 501, "+"], ["3", "37", 601, "+"],
          ["3", "38", 701, "+"]],
         [["2", "21", 1, "+"], ["2", "22", 101, "+"], ["2", "23", 201, "+"], ["2", "24", 301, "+"],
          ["2", "25", 401, "+"], ["2", "27", 601, "+"], ["2", "28", 701, "+"], ["2", "29", 801, "+"]],
         2, 100, does_not_raise()),
        # `gene1` not found in `neighbourhood1
        ("42", "62",
         [["4", "41", 1, "-"], ["4", "43", 201, "+"]],
         [["6", "61", 1, "-"], ["6", "62", 101, "+"], ["6", "63", 201, "+"]],
         1, None, raises(ValueError,
                         match=r"Gene '42' not found in corresponding neighbourhood dataframe.")),
        # `gene2` not found in `neighbourhood2`
        ("42", "62",
         [["4", "41", 1, "-"], ["4", "42", 101, "-"], ["4", "43", 201, "+"]],
         [["6", "61", 1, "-"], ["6", "63", 201, "+"]],
         1, None, raises(ValueError,
                         match=r"Gene '62' not found in corresponding neighbourhood dataframe.")),
        # Empty neighbourhood of a query gene
        ("42", "62",
         [],
         [["6", "61", 1, "-"], ["6", "62", 101, "+"], ["6", "63", 201, "+"]],
         1, None, raises(ValueError,
                         match=r"Gene '42' not found in corresponding neighbourhood dataframe.")),
        # `gene1` has invalid strand (neither + nor -)
        # [checked by :func:`check_neighbourhood_valid_for_goc()`]
        ("42", "62",
         [["4", "41", 1, "-"], ["4", "42", 101, "*"], ["4", "43", 201, "+"]],
         [["6", "61", 1, "-"], ["6", "62", 101, "+"], ["6", "63", 201, "+"]],
         1, None, raises(ValueError,
                         match=re.escape(r"The strand of gene '42' is neither + nor -."))),
    ]
)
def test_calculate_goc_genes(gene1: str, gene2: str, neighbours1: List[Tuple[str, str, int, str]],
                             neighbours2: List[Tuple[str, str, int, str]], n: int, exp_out: float,
                             expectation: ContextManager) -> None:
    """Tests :func:`orthology_benchmark.calculate_goc_genes()` function.

    Args:
        gene1: `gene_id` of one gene of interest.
        gene2: `gene_id` of another gene of interest.
        neighbours1: A list of lists containing information about neighbours of `gene1` (GTF "seqname",
            "gene_id", "start", "strand").
        neighbours2: A list of lists containing information about neighbours of `gene2` (GTF "seqname",
            "gene_id", "start", "strand").
        n: (Maximum) Radius of `gene1`'s neighbourhood. Effectively, the neighbourhood can be smaller if
            there are fewer genes around `gene1`.
        exp_out: Expected return value of the function.
        expectation: Context manager for the expected exception, i.e. the test will only pass if that
            exception is raised. Use :class:`~contextlib.nullcontext` if no exception is expected.

    """
    orthologs = [("11", "35"), ("21", "35"), ("22", "36"), ("23", "31"), ("23", "38"), ("24", "32"),
                 ("25", "33"), ("26", "33"), ("27", "34"), ("28", "39"), ("29", "37"), ("41", "56"),
                 ("41", "63"), ("42", "55"), ("42", "62"), ("43", "53"), ("43", "61"), ("45", "52"),
                 ("46", "51"), ("47", "54"), ("72", "82"), ("73", "87")]

    with expectation:
        neighbourhood1 = pandas.DataFrame(neighbours1, columns=["seqname", "gene_id", "start", "strand"])
        neighbourhood2 = pandas.DataFrame(neighbours2, columns=["seqname", "gene_id", "start", "strand"])
        assert orthology_benchmark.calculate_goc_genes(
            gene1, gene2, neighbourhood1, neighbourhood2, orthologs, n
        ) == exp_out


def test_calculate_goc_genes_atypical_input() -> None:
    """Tests :func:`orthology_benchmark.calculate_goc_genes()` function when gene neighbourhood data frames
    contain only information needed for GOC score calculation and nothing beyond it.

    This is not supposed to be the case for Benchmark Orthology pipeline.

    """
    orthologs = [("41", "56"), ("41", "63"), ("42", "55"), ("42", "62"), ("43", "53"), ("43", "61")]

    columns = ["gene_id", "strand"]
    neighbourhood1 = pandas.DataFrame([["41", "-"], ["42", "-"], ["43", "+"]], columns=columns)
    neighbourhood2 = pandas.DataFrame([["61", "-"], ["62", "+"], ["63", "+"]], columns=columns)

    assert orthology_benchmark.calculate_goc_genes(
        "42", "62", neighbourhood1, neighbourhood2, orthologs, 1
    ) == 100
