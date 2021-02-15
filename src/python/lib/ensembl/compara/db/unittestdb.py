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
"""Unit testing database handler.

This module provides the main class to create and drop unit testing databases, populating them from
preexisting dumps (if supplied).

Typical usage example::

    db = UnitTestDB('mysql://ensro@mysql-server:4242/', 'path/to/dumps', 'my_db')
    # You can access the database via db.dbc, for instance:
    results = db.dbc.execute('SELECT * FROM my_table;')
    # At the end do not forget to drop the database:
    db.drop()

"""

from pathlib import Path
import os
import re
import subprocess
from typing import Iterator, Union

import sqlalchemy
from sqlalchemy import create_engine, text
from sqlalchemy.engine.url import make_url

from ..filesys import PathLike
from .dbconnection import DBConnection, Query, URL


class UnitTestDB:
    """Creates and connects to a new database, applying the schema and importing the data.

    Args:
        url: URL of the server hosting the database, e.g. ``mysql://user:passwd@localhost:3306/``, or SQLite
            path URL, e.g. ``sqlite:////path/to/database/dir/``. The user needs to have write access to the
            server/directory.
        dump_dir: Directory path with the database schema in ``table.sql`` [mandatory] and the TSV data files
            (without headers), one per table following the convention ``<table_name>.txt`` [optional].
        name: Name to give to the new database. If not provided, the last directory name of `dump_dir` will be
            used instead. In either case, the new database name will be prefixed by the username.

    Attributes:
        dbc (DBConnection): Database connection handler.

    Raises:
        FileNotFoundError: If `dump_dir` is not an existing directory; or if the schema file ``table.sql`` is
            not found in `dump_dir`.

    """

    def __init__(self, url: URL, dump_dir: PathLike, name: str = None) -> None:
        db_url = make_url(url)
        dump_dir_path = Path(dump_dir)
        if db_url.get_dialect().name == 'sqlite':
            # SQLite databases are created automatically if they do not exist
            db_url.database += '/' + os.environ['USER'] + '_' + (name if name else dump_dir_path.name) + '.db'
        else:
            # Add the database name to the URL
            db_url.database = os.environ['USER'] + '_' + (name if name else dump_dir_path.name)
            # Connect to the server to create the database
            self._server = create_engine(url)
            self._server.execute(text(f"CREATE DATABASE {db_url.database};"))
        try:
            # Establish the connection to the database, load the schema and import the data
            self.dbc = DBConnection(db_url)
            with self.dbc.begin() as conn:
                for query in self._parse_sql_file(dump_dir_path / 'table.sql'):
                    conn.execute(query)
                    table = self._get_table_name(query)
                    filepath = dump_dir_path / f"{table}.txt"
                    if table and filepath.exists():
                        self._load_data(conn, table, filepath)
        except:
            # Make sure the database is deleted before raising the exception
            self.drop()
            raise
        # Update the loaded metadata information of the database
        self.dbc.load_metadata()

    def __repr__(self) -> str:
        """Returns a string representation of the object."""
        return f"{self.__class__.__name__}({self.dbc.url!r})"

    def drop(self) -> None:
        """Drops the database."""
        if self.dbc.dialect == 'sqlite':
            os.remove(self.dbc.db_name)
        else:
            self._server.execute(text(f"DROP DATABASE {self.dbc.db_name};"))
        self.dbc.dispose()

    def _load_data(self, conn: sqlalchemy.engine.Connection, table: str, filepath: PathLike) -> None:
        """Loads the table data from the given file.

        Args:
            conn: Open connection to the database.
            table: Table name to load the data to.
            filepath: File path with the data in TSV format (without headers).

        Raises:
            UnitTestDBError: if ``.import`` command fails (SQLite databases only).

        """
        if self.dbc.dialect == 'sqlite':
            # SQLite does not have an equivalent to "LOAD DATA": use its '.import' command
            try:
                subprocess.run(
                    ['sqlite3', self.dbc.db_name, ".mode tabs", f".import {filepath} {table}"],
                    check=True
                )
            except subprocess.CalledProcessError:
                raise DataLoadingError(f"SQLite3 import of '{filepath}' failed") from None
        elif self.dbc.dialect == 'postgresql':
            conn.execute(text(f"COPY {table} FROM '{filepath}'"))
        elif self.dbc.dialect == 'sqlserver':
            conn.execute(text(f"BULK INSERT {table} FROM '{filepath}'"))
        else:
            conn.execute(text(f"LOAD DATA LOCAL INFILE '{filepath}' INTO TABLE {table}"))

    @staticmethod
    def _parse_sql_file(filepath: Union[bytes, PathLike]) -> Iterator[sqlalchemy.sql.expression.TextClause]:
        """Yields each SQL query found parsing the given SQL file.

        Args:
            filepath: SQL file path.

        """
        with open(filepath) as sql_file:
            query = []
            multiline_comment = False
            for line in sql_file:
                line = line.strip(' \n')
                # Capture (and discard) multiple-line comments
                if re.match(r'\/\*\*', line):
                    multiline_comment = True
                    continue
                if re.search(r'\*\/$', line):
                    multiline_comment = False
                    continue
                if not multiline_comment:
                    # Remove single- and in-line comments
                    line = re.sub(r'(--|#|\/\/).*', '', line)
                    line = re.sub(r'\/\*[^\*]*\*\/', '', line)
                    if line:
                        query.append(line)
                        if line.endswith(';'):
                            yield text(' '.join(query))
                            query = []

    @staticmethod
    def _get_table_name(query: Query) -> str:
        """Returns the table name of a ``CREATE TABLE`` SQL query, empty string otherwise."""
        match = re.search(r'^CREATE[ ]+TABLE[ ]+(`[^`]+`|[^ ]+)', str(query))
        return match.group(1).strip('`') if match else ''


class UnitTestDBError(Exception):
    """Base class for all other exceptions from this module."""


class DataLoadingError(UnitTestDBError):
    """Raised when the data loading fails."""
