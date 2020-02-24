"""
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

from typing import Dict, List, Union

import pandas
import pytest
from _pytest._code.code import ExceptionChainRepr, ExceptionInfo, ReprExceptionInfo
from _pytest.fixtures import FixtureLookupErrorRepr
from sqlalchemy import func
from sqlalchemy.sql.expression import select, text

from compara import to_list
from compara.citest._citest import CITestItem
from compara.db import DBConnection


class TestDBItem(CITestItem):
    """Generic tests to compare a table in two (analogous) Ensembl Compara MySQL databases.

    Args:
        name: Name of the test to run.
        parent: The parent collector node.
        ref_db: Database connectivity and features of the reference database.
        target_db: Database connectivity and features of the target database.
        table: Table to be tested.
        args: Arguments to pass to the test call.

    Attributes:
        ref_db (DBConn): Database connectivity and features of the reference database.
        target_db (DBConn): Database connectivity and features of the target database.
        table (str): Table to be tested.

    """
    def __init__(self, name: str, parent: pytest.Item, ref_db: DBConnection, target_db: DBConnection,
                 table: str, args: Dict) -> None:
        super().__init__(name, parent, args)
        self.ref_db = ref_db
        self.target_db = target_db
        self.table = table

    def repr_failure(self, excinfo: ExceptionInfo, style: str = None
                    ) -> Union[str, ReprExceptionInfo, ExceptionChainRepr, FixtureLookupErrorRepr]:
        """Returns the failure representation that will be displayed in the report section.

        Note:
            This method is called when ``self.runtest()`` raises an exception.

        Args:
            excinfo: Exception information with additional support for navigating and traceback.
            style: Traceback print mode (``auto``/``long``/``short``/``line``/``native``/``no``).

        """
        if isinstance(excinfo.value, FailedDBTestException):
            self.error_info['expected'] = excinfo.value.args[0]
            self.error_info['found'] = excinfo.value.args[1]
            self.error_info['query'] = str(excinfo.value.args[2]).replace('\n', '').strip()
            return excinfo.value.args[3] + "\n"
        if isinstance(excinfo.value, AssertionError):
            return excinfo.value.args[0] + "\n"
        return super().repr_failure(excinfo, style)

    def get_report_header(self) -> str:
        """Returns the header to display in the error report."""
        return f"Database table: {self.table}, test: {self.name}"

    def test_num_rows(self, variation: float = 0.0, group_by: Union[str, List] = None,
                      filter_by: Union[str, List] = None) -> None:
        """Compares the number of rows between reference and target tables.

        If `group_by` is provided, the number of rows will be compared per group, applying the same variation
        to all of them. If `filter_by` is provided, only the rows matching all the given conditions will be
        compared.

        Args:
            variation: Allowed variation between reference and target tables.
            group_by: Group rows by column(s), and count the number of rows per group.
            filter_by: Filter rows by one or more conditions (joined by the AND operator).

        Raise:
            FailedDBTestException: If `group_by` is provided and the number of groups is different; or if the
                number of rows differ for at least one group.

        """
        # Compose the sql query from the given parameters (both databases should have the same table schema)
        table = self.ref_db.tables[self.table]
        columns = [table.columns[col] for col in to_list(group_by)]
        # Use primary key in count to improve the query performance
        primary_key = table.primary_key.columns.values()[0].name
        query = select(columns + [func.count(table.columns[primary_key]).label('nrows')])
        if columns:
            # ORDER BY to ensure that the results are always in the same order (for the same groups)
            query = query.group_by(*columns).order_by(*columns)
        for clause in to_list(filter_by):
            query = query.where(text(clause))
        # Get the number of rows for both databases
        ref_data = pandas.read_sql(query, self.ref_db.connect())
        target_data = pandas.read_sql(query, self.target_db.connect())
        # Check if the size of the returned tables are the same
        if ref_data.shape != target_data.shape:
            expected = ref_data.shape[0]
            found = target_data.shape[0]
            # Note that the shape can only be different if group_by is given
            message = (
                f"Different number of groups ({', '.join([c.name for c in columns])}) for table "
                f"'{self.table}'"
            )
            raise FailedDBTestException(expected, found, query, message)
        # Check if the number of rows (per group) are the same
        difference = abs(ref_data['nrows'] - target_data['nrows'])
        allowed_variation = ref_data['nrows'] * variation
        failing_rows = difference > allowed_variation
        if failing_rows.any():
            expected_data = ref_data.loc[failing_rows]
            expected = [] if expected_data.empty else expected_data.to_string(index=False).splitlines()
            found_data = target_data.loc[failing_rows]
            found = [] if found_data.empty else found_data.to_string(index=False).splitlines()
            message = (
                f"The difference in number of rows for table '{self.table}' exceeds the allowed variation "
                f"({variation})"
            )
            raise FailedDBTestException(expected, found, query, message)

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
            AssertionError: If both ``columns`` and ``ignore_columns`` are provided.
            FailedDBTestException: If the number of rows differ; or if one or more rows have different
                content.

        """
        assert not (columns and ignore_columns), "Expected only 'columns' or 'ignore_columns', not both"
        # Compose the sql query from the given parameters (both databases should have the same table schema)
        table = self.ref_db.tables[self.table]
        if ignore_columns:
            ignore_columns = to_list(ignore_columns)
            db_columns = [col for col in table.columns if col.name not in ignore_columns]
            columns = [col.name for col in db_columns]
        else:
            columns = to_list(columns)
            db_columns = [table.columns[col] for col in columns]
        query = select(db_columns)
        for clause in to_list(filter_by):
            query = query.where(text(clause))
        # Get the table content for the selected columns
        ref_data = pandas.read_sql(query, self.ref_db.connect())
        target_data = pandas.read_sql(query, self.target_db.connect())
        # Check if the size of the returned tables are the same
        # Note: although not necessary, this control provides a better error message
        if ref_data.shape != target_data.shape:
            expected = ref_data.shape[0]
            found = target_data.shape[0]
            message = f"Different number of rows in table '{self.table}'"
            raise FailedDBTestException(expected, found, query, message)
        # Compare the content of both dataframes, sorting them first to ensure they are comparable
        ref_data.sort_values(by=columns, inplace=True, kind='mergesort')
        target_data.sort_values(by=columns, inplace=True, kind='mergesort')
        failing_rows = ref_data.ne(target_data).any(axis='columns')
        if failing_rows.any():
            expected_data = ref_data.loc[failing_rows]
            expected = [] if expected_data.empty else expected_data.to_string(index=False).splitlines()
            found_data = target_data.loc[failing_rows]
            found = [] if found_data.empty else found_data.to_string(index=False).splitlines()
            message = f"Table '{self.table}' has different content for columns {', '.join(columns)}"
            raise FailedDBTestException(expected, found, query, message)


class FailedDBTestException(Exception):
    """Exception subclass created to handle test failures separatedly from unexpected exceptions."""
