# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
"""Module docstring"""
# TODO: write module docstring

from logging import Logger
import operator
import re
from typing import List, Union

import numpy
import pandas
import pytest
from _pytest.fixtures import FixtureRequest
from sqlalchemy import create_engine
from sqlalchemy.schema import MetaData


class TestDBException(Exception):
    """Exception subclass created to handle test failures separatedly from unexpected exceptions."""
    pass


# Hide the exception traceback only for those exceptions raised intentionally due to a failed test
__tracebackhide__ = operator.methodcaller("errisinstance", TestDBException)


class TestDB:
    """Generic tests to compare two (analogous) Ensembl Compara MySQL databases.

    Args:
        ref_url: URL to the reference database, e.g. "mysql://ensro@mysql-ens-compara-prod-8:4618/my_db".
        target_url: URL to the target database, e.g. "mysql://ensro@mysql-ens-compara-prod-8:4618/my_db".
        log: If a log handler is passed, the reference and target Engines will log all statements as well as
            a repr() of their parameter lists to it.

    Attributes:
        ref_engine (engine.Engine): Source of database connectivity and behavior to the reference database.
        ref_metadata (schema.Metadata): Container for many different features of the reference database.
        target_engine (Engine): Source of database connectivity and behavior to the target database.
        target_metadata (schema.Metadata): Container for many different features of the target database.
    """
    def __init__(self, ref_url: str, target_url: str, log: Logger = None):
        self.ref_engine = create_engine(ref_url, echo=log)
        self.ref_metadata = MetaData(bind=self.ref_engine)
        self.ref_metadata.reflect()
        self.target_engine = create_engine(target_url, echo=log)
        self.target_metadata = MetaData(bind=self.target_engine)
        self.target_metadata.reflect()

    def test_num_rows(self, request: FixtureRequest, table_name: str, *args, variation: float = 0.0,
                      group_by: Union[str, List] = "", filter_by: Union[str, List] = "", **kwargs) -> None:
        """Compares the number of rows of the given table between reference and target databases.

        If group_by is provided, the number of rows will be compared per group, applying the same variation
        to all of them. If filter_by is provided, only the rows matching all the given conditions will be
        compared.

        Note:
            The ceiling function is applied to round the allowed variation in order to compare two integers.
            Thus, the test may pass even if the row difference between both databases is greater than the
            exact allowed variation, e.g. row difference is 2 and the allowed variation is 1,4.

        Args:
            request: Special fixture providing information of the requesting test function.
            table_name: Name of the table to get the number of rows from.
            variation: Allowed variation between reference and target tables.
            group_by: Group rows by column(s), and count the number of rows per group.
            filter_by: Filter rows by one or more conditions. If a list is provided, the elements will be
                joined by "AND".
        """
        # Compose the sql query from the given parameters
        sql_filter = self._get_sql_filter(filter_by)
        if group_by:
            if isinstance(group_by, list):
                group_by = ", ".join(group_by)
            # ORDER BY to ensure that the results are always in the same order (for the same groups)
            sql_query = "SELECT {0}, COUNT(*) as nrows FROM {1} {2} GROUP BY {0} ORDER BY {0}".format(
                group_by, table_name, sql_filter)
        else:
            sql_query = "SELECT COUNT(*) as nrows FROM {} {}".format(table_name, sql_filter)
        # Get the number of rows for both databases
        result = self.ref_engine.execute(sql_query)
        ref_data = pandas.DataFrame(result.fetchall(), columns=result.keys())
        result = self.target_engine.execute(sql_query)
        target_data = pandas.DataFrame(result.fetchall(), columns=result.keys())
        # Check if the size of the returned tables are the same
        if ref_data.shape != target_data.shape:
            request.node.error_info = {"expected": ref_data.shape[0],
                                       "found":    target_data.shape[0],
                                       "query":    sql_query.strip()}
            raise TestDBException(
                "Different number of groups ({}) for table '{}'".format(group_by, table_name))
        # Check if the number of rows (per group) are the same
        difference = abs(ref_data["nrows"] - target_data["nrows"])
        allowed_variation = numpy.ceil(ref_data["nrows"] * variation)
        failing_rows = difference > allowed_variation
        if failing_rows.any():
            request.node.error_info = {"expected": ref_data.loc[failing_rows].values.tolist(),
                                       "found":    target_data.loc[failing_rows].values.tolist(),
                                       "query":    sql_query.strip()}
            raise TestDBException(
                "The difference in number of rows for table '{}' exceeds the allowed variation ({})".format(
                    table_name, variation)
            )

    def test_table_content(self, request: FixtureRequest, table_name: str, *args,
                           columns: Union[str, List] = "", filter_by: Union[str, List] = "",
                           **kwargs) -> None:
        """Compares the content of the given table between reference and target databases.

        The comparison is made only for the selected columns. The data and the data type of each column have
        to be the same in the reference and target tables in order to be considered equal.

        Args:
            request: Special fixture providing information of the requesting test function.
            table_name: Name of the table to compare.
            columns: Columns to take into account in the comparison. If an empty string/list is provided, all
                columns will be included. Alternatively, it can be an exclusion list by adding a "-" at the
                start of each column name, e.g. "-job_id" will make all columns but "job_id" to be included.
            filter_by: Filter rows by one or more conditions. If a list is provided, the elements will be
                joined by the AND operator.
        """
        sql_filter = self._get_sql_filter(filter_by)
        if isinstance(columns, str):
            columns = [columns] if columns else []
        if (not columns or all(col.startswith("-") for col in columns)):
            # Retrieve all the columns from the table and remove those in the exclusion list
            ref_columns = [col.name for col in self.ref_metadata.tables[table_name].columns]
            for col in columns:
                ref_columns.remove(col[1:])
            columns = ref_columns
        # Compose the sql query from the given parameters
        sql_query = "SELECT `{}` FROM {} {}".format("`,`".join(columns), table_name, sql_filter)
        # Get the table content for the selected columns
        result = self.ref_engine.execute(sql_query)
        ref_data = pandas.DataFrame(result.fetchall(), columns=result.keys())
        result = self.target_engine.execute(sql_query)
        target_data = pandas.DataFrame(result.fetchall(), columns=result.keys())
        # Check if the size of the returned tables are the same
        if ref_data.shape != target_data.shape:
            request.node.error_info = {"expected": ref_data.shape[0],
                                       "found":    target_data.shape[0],
                                       "query":    sql_query.strip()}
            message = "Different number of rows in table '{}'".format(table_name)
            if len(columns) != len(self.ref_metadata.tables[table_name].columns):
                message += " (columns {})".format(", ".join(columns))
            raise TestDBException(message)
        # Compare the content of both dataframes, sorting them first to ensure they are comparable
        ref_data.sort_values(by=columns, inplace=True, kind="mergesort")
        target_data.sort_values(by=columns, inplace=True, kind="mergesort")
        failing_rows = ref_data.ne(target_data).any(axis="columns")
        if failing_rows.any():
            request.node.error_info = {"expected": ref_data.loc[failing_rows].values.tolist(),
                                       "found":    target_data.loc[failing_rows].values.tolist(),
                                       "query":    sql_query.strip()}
            raise TestDBException(
                "Table '{}' has different content for columns {}".format(table_name, ", ".join(columns)))

    @staticmethod
    def _get_sql_filter(filter_by: Union[str, List]) -> str:
        """Returns an SQL WHERE clause including all the given conditions.

        If more than one condition is given, they will be joined by the AND operator and put inside
        parenthesis. Symbols that can be considered placeholders by sqlalchemy (like "%") will be doubled
        ("%%") to keep their initial meaning.

        Args:
            filter_by: Condition(s) to be combined in the WHERE statement.

        Returns:
            An empty string if filter_by is empty, the SQL WHERE clause otherwise.
        """
        sql_filter = ""
        if filter_by:
            if isinstance(filter_by, list):
                filter_by = ") AND (".join(filter_by)
            # Single percentage symbols ("%") are interpreted as placeholders, so double them up
            filter_by = re.sub(r'(?<!%)%(?!%)', '%%', filter_by)
            sql_filter = "WHERE ({})".format(filter_by)
        return sql_filter
