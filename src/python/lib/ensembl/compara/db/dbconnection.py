"""
See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

import contextlib
from typing import Dict, List, TypeVar

import sqlalchemy
from sqlalchemy import create_engine, event, text
from sqlalchemy.orm.session import Session
from sqlalchemy.sql import select


# Create the Query type as an alias for all the possible types an SQL query can be stored into
Query = TypeVar('Query', str, sqlalchemy.sql.expression.ClauseElement)
# Create the URL type as an alias for all the possible types an URL can be stored into
URL = TypeVar('URL', str, sqlalchemy.engine.url.URL)


class DBConnection:
    """Database connection handler, providing also the database's schema and properties.

    Args:
        url: URL to the database, e.g. ``mysql://user:passwd@host:port/my_db``.

    """
    def __init__(self, url: URL) -> None:
        self._engine = create_engine(url)
        self.load_metadata()

    def load_metadata(self) -> None:
        """Loads the metadata information of the database."""
        # Note: Just reflect() is not enough as it would not delete tables that no longer exist
        self._metadata = sqlalchemy.MetaData(bind=self._engine)
        self._metadata.reflect()

    @property
    def url(self) -> str:
        """Returns the database URL."""
        return str(self._engine.url)

    @property
    def db_name(self) -> str:
        """Returns the database name."""
        return self._engine.url.database

    @property
    def host(self) -> str:
        """Returns the database host."""
        return self._engine.url.host

    @property
    def dialect(self) -> str:
        """Returns the SQLAlchemy database dialect of the database host."""
        return self._engine.name

    @property
    def tables(self) -> Dict[str, sqlalchemy.schema.Table]:
        """Returns a dictionary of :class:`~sqlalchemy.schema.Table` objects keyed to their name."""
        return self._metadata.tables

    def get_primary_key_columns(self, table: str) -> List[str]:
        """Returns the list of primary key column names for the given table.

        Args:
            table: Table name.

        """
        return [col.name for col in self.tables[table].primary_key.columns.values()]

    def get_columns(self, table: str) -> List[str]:
        """Returns the list of column names for the given table.

        Args:
            table: Table name.

        """
        return [col.name for col in self.tables[table].columns]

    @property
    def schema_type(self) -> str:
        """Returns the schema type of the database, located in the ``meta`` table."""
        result = self.execute(
            select([self.tables['meta'].columns.meta_value]).where(text('meta_key = "schema_type"'))
        )
        return result.first()[0]

    @property
    def schema_version(self) -> int:
        """Returns the schema version of the database, located in the ``meta`` table."""
        result = self.execute(
            select([self.tables['meta'].columns.meta_value]).where(text('meta_key = "schema_version"'))
        )
        return int(result.first()[0])

    def connect(self) -> sqlalchemy.engine.Connection:
        """Returns a new :class:`~sqlalchemy.engine.Connection` object."""
        return self._engine.connect()

    def begin(self, *args) -> sqlalchemy.engine.Connection:
        """Returns a context manager delivering a :class:`~sqlalchemy.engine.Connection` with a
        :class:`~sqlalchemy.engine.Transaction` established.
        """
        return self._engine.begin(*args)

    def dispose(self) -> None:
        """Disposes of the connection pool."""
        self._engine.dispose()

    def execute(self, statement: Query, *multiparams, **params) -> sqlalchemy.engine.ResultProxy:
        """Executes the given SQL query and returns a :class:`~sqlalchemy.engine.ResultProxy`.

        Args:
            statement: SQL query to execute.
            *multiparams/**params: Bound parameter values to be used in the execution of the query.

        """
        if isinstance(statement, str):
            statement = text(statement)
        return self._engine.execute(statement, *multiparams, **params)

    @contextlib.contextmanager
    def session_scope(self) -> Session:
        """Provides a transactional scope around a series of operations with rollback in case of failure.

        Note:
            MySQL storage engine MyISAM does not support rollback transactions, so all the modifications
            performed to the database will persist.

        """
        session = Session(bind=self._engine, autoflush=False)
        try:
            yield session
            session.commit()
        except:
            # Rollback to ensure no changes are made to the database
            session.rollback()
            raise
        finally:
            # Whatever happens, make sure the session is closed
            session.close()

    @contextlib.contextmanager
    def test_session_scope(self) -> Session:
        """Provides a transactional scope around a series of operations that will be rolled back at the end.

        Note:
            MySQL storage engine MyISAM does not support rollback transactions, so all the modifications
            performed to the database will persist.

        """
        # Connect to the database
        connection = self.connect()
        # Begin a non-ORM transaction
        transaction = connection.begin()
        # Bind an individual Session to the connection
        session = Session(bind=connection)
        # Start the session in a SAVEPOINT
        session.begin_nested()
        # Define a new transaction event
        @event.listens_for(session, "after_transaction_end")
        def restart_savepoint(session, transaction):  # pylint: disable=unused-variable
            """Reopen a SAVEPOINT whenever the previous one ends."""
            if transaction.nested and not transaction._parent.nested:  # pylint: disable=protected-access
                # Ensure that state is expired the same way session.commit() at the top level normally does
                session.expire_all()
                session.begin_nested()
        try:
            yield session
        finally:
            # Whatever happens, make sure the session and connection are closed, rolling back everything done
            # with the session (including calls to commit())
            session.close()
            transaction.rollback()
            connection.close()
