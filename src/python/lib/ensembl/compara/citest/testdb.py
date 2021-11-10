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
"""CITest database comparison module."""

__all__ = ['CITestDBItem', 'CITestDBError', 'CITestDBContentError', 'CITestDBGroupingError',
           'CITestDBNumRowsError']

from typing import Any, Dict, List, Union

import pandas
import pytest
from _pytest._code.code import ExceptionChainRepr, ExceptionInfo, ReprExceptionInfo
from _pytest.fixtures import FixtureLookupErrorRepr
from sqlalchemy import func
from sqlalchemy.sql.expression import select, text

from ensembl.database import Query, DBConnection
from ..utils import to_list
from ._citest import CITestItem


class CITestDBItem(CITestItem):
    """Generic tests to compare a table in two (analogous) Ensembl Compara MySQL databases.

    Args:
        name: Name of the test to run.
        parent: The parent collector node.
        ref_dbc: Reference database connection handler.
        target_dbc: Target database connection handler.
        table: Table to be tested.
        args: Arguments to pass to the test call.

    Attributes:
        ref_dbc (DBConnection): Reference database connection handler.
        target_dbc (DBConnection): Target database connection handler.
        table (str): Table to be tested.

    """
    def __init__(self, name: str, parent: pytest.Item, ref_dbc: DBConnection, target_dbc: DBConnection,
                 table: str, args: Dict) -> None:
        super().__init__(name, parent, args)
        self.ref_dbc = ref_dbc
        self.target_dbc = target_dbc
        self.table = table

    def repr_failure(self, excinfo: ExceptionInfo, style: str = None
                    ) -> Union[str, ReprExceptionInfo, ExceptionChainRepr, FixtureLookupErrorRepr]:
        """Returns the failure representation that will be displayed in the report section.

        Note:
            This method is called when :meth:`CITestDBItem.runtest()` raises an exception.

        Args:
            excinfo: Exception information with additional support for navigating and traceback.
            style: Traceback print mode (``auto``/``long``/``short``/``line``/``native``/``no``).

        """
        if isinstance(excinfo.value, CITestDBError):
            self.error_info['expected'] = excinfo.value.expected
            self.error_info['found'] = excinfo.value.found
            self.error_info['query'] = excinfo.value.query
            return excinfo.value.args[0] + "\n"
        if isinstance(excinfo.value, TypeError):
            return excinfo.value.args[0] + "\n"
        return super().repr_failure(excinfo, style)

    def get_report_header(self) -> str:
        """Returns the header to display in the error report."""
        return f"Database table: {self.table}, test: {self.name}"

    def test_num_rows(self, variation: float = 0.0, group_by: Union[str, List] = None,
                      filter_by: Union[str, List] = None) -> None:
        """Compares the number of rows between reference and target tables.

        If `group_by` is provided, the same variation will be applied to each group.

        Args:
            variation: Allowed variation between reference and target tables.
            group_by: Group rows by column(s), and count the number of rows per group.
            filter_by: Filter rows by one or more conditions (joined by the AND operator).

        Raise:
            CITestDBGroupingError: If `group_by` is provided and the groups returned are different.
            CITestDBNumRowsError: If the number of rows differ more than the expected variation for at least
                one group.

        """
        # Compose the SQL query from the given parameters (both databases should have the same table schema)
        table = self.ref_dbc.tables[self.table]
        group_by = to_list(group_by)
        columns = [table.columns[col] for col in group_by]
        # Use primary key (if any) in count to improve the query performance
        primary_keys = self.ref_dbc.get_primary_key_columns(self.table)
        primary_key_col = table.columns[primary_keys[0]] if primary_keys else None
        query = select(columns + [func.count(primary_key_col).label('nrows')]).select_from(table)
        if columns:
            # ORDER BY to ensure that the results are always in the same order (for the same groups)
            query = query.group_by(*columns).order_by(*columns)
        for clause in to_list(filter_by):
            query = query.where(text(clause))
        # Get the number of rows for both databases
        ref_data = pandas.read_sql(query, self.ref_dbc.connect())
        target_data = pandas.read_sql(query, self.target_dbc.connect())
        if group_by:
            # Check if the groups returned are the same
            merged_data = ref_data.merge(target_data, on=group_by, how='outer', indicator=True)
            if not merged_data[merged_data['_merge'] != 'both'].empty:
                # Remove columns "nrows_x", "nrows_y" and "_merge" in the dataframes to include in the report
                ref_only = merged_data[merged_data['_merge'] == 'left_only'].iloc[:, :-3]
                target_only = merged_data[merged_data['_merge'] == 'right_only'].iloc[:, :-3]
                raise CITestDBGroupingError(self.table, ref_only, target_only, query)
        # Check if the number of rows (per group) are within the allowed variation
        difference = abs(ref_data['nrows'] - target_data['nrows'])
        allowed_variation = ref_data['nrows'] * variation
        failing_rows = difference > allowed_variation
        if failing_rows.any():
            raise CITestDBNumRowsError(self.table, ref_data.loc[failing_rows], target_data.loc[failing_rows],
                                       query)

    def test_content(self, *, columns: Union[str, List] = None, ignore_columns: Union[str, List] = None,
                     filter_by: Union[str, List] = None) -> None:
        """Compares the content between reference and target tables.

        The data and the data type of each column have to be the same in both tables in order to be considered
        equal.

        Args:
            columns: Columns to take into account in the comparison.
            ignore_columns: Columns to exclude in the comparison, i.e. all columns but those included in this
                parameter will be compared.
            filter_by: Filter rows by one or more conditions (joined by the AND operator).

        Raise:
            TypeError: If both `columns` and `ignore_columns` are provided.
            CITestDBNumRowsError: If the number of rows differ.
            CITestDBContentError: If one or more rows have different content.

        """
        if columns and ignore_columns:
            raise TypeError("Expected either 'columns' or 'ignore_columns', not both")
        # Compose the SQL query from the given parameters (both databases should have the same table schema)
        table = self.ref_dbc.tables[self.table]
        if columns:
            columns = to_list(columns)
            db_columns = [table.columns[col] for col in columns]
        else:
            ignore_columns = to_list(ignore_columns)
            db_columns = [col for col in table.columns if col.name not in ignore_columns]
            columns = [col.name for col in db_columns]
        query = select(db_columns)
        for clause in to_list(filter_by):
            query = query.where(text(clause))
        # Get the table content for the selected columns
        ref_data = pandas.read_sql(query, self.ref_dbc.connect())
        target_data = pandas.read_sql(query, self.target_dbc.connect())
        # Check if the size of the returned tables are the same
        # Note: although not necessary, this control provides a better error message
        if ref_data.shape != target_data.shape:
            raise CITestDBNumRowsError(self.table, ref_data.shape[0], target_data.shape[0], query)
        # Compare the content of both dataframes
        merged_data = ref_data.merge(target_data, how='outer', indicator=True)
        if not merged_data[merged_data['_merge'] != 'both'].empty:
            # Remove column "_merge" in the dataframes to include in the report
            ref_only = merged_data[merged_data['_merge'] == 'left_only'].iloc[:, :-1]
            target_only = merged_data[merged_data['_merge'] == 'right_only'].iloc[:, :-1]
            raise CITestDBContentError(self.table, ref_only, target_only, query)


class CITestDBError(Exception):
    """Exception subclass created to handle test failures separatedly from unexpected exceptions.

    Args:
        message: Error message to display.
        expected: Expected value(s) (reference database).
        found: Value(s) found (target database).
        query: SQL query used to retrieve the information.

    Attributes:
        expected (Any): Expected value(s) (reference database).
        found (Any): Value(s) found (target database).
        query (Query): SQL query used to retrieve the information.

    """
    def __init__(self, message: str, expected: Any, found: Any, query: Query) -> None:
        super().__init__(message)
        self.expected = self._parse_data(expected)
        self.found = self._parse_data(found)
        self.query = str(query).replace('\n', '').strip()

    @staticmethod
    def _parse_data(data: Any) -> Any:
        """Returns a list representation of `data` if it is a dataframe, `data` otherwise."""
        if isinstance(data, pandas.DataFrame):
            # Avoid the default list representation for empty dataframes:
            #     ['Empty DataFrame', 'Columns: []', 'Index: []']
            return [] if data.empty else data.to_string(index=False).splitlines()
        return data


class CITestDBContentError(CITestDBError):
    """Exception raised when `table` has different content in reference and target databases."""
    def __init__(self, table: str, *args: Any) -> None:
        message = f"Different content found in table '{table}'"
        super().__init__(message, *args)


class CITestDBGroupingError(CITestDBError):
    """Exception raised when `table` returns different groups for reference and target databases."""
    def __init__(self, table: str, *args: Any) -> None:
        message = f"Different groups found for table '{table}'"
        super().__init__(message, *args)


class CITestDBNumRowsError(CITestDBError):
    """Exception raised when `table` has different number of rows in reference and target databases."""
    def __init__(self, table: str, *args: Any) -> None:
        message = f"Different number of rows for table '{table}'"
        super().__init__(message, *args)
