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
"""Database connection handler, providing additional functionality around DBIs database handle."""

from sqlalchemy.engine import ResultProxy
from sqlalchemy.schema import MetaData


class DBConnection(MetaData):
    """Database connection that holds the collection of Table objects and their associated schema.

    Args:
        url: URL to the database, e.g. "mysql://ensro@mysql-ens-compara-prod-8:4618/my_db".

    """
    def __init__(self, url: str) -> None:
        # Automatically create the database connection and load all tables
        super().__init__(bind=url)
        self.reflect()

    def execute(self, query: str) -> ResultProxy:
        """Returns the result of executing the given SQL query against the database.

        Args:
            query: SQL query.

        """
        return self.bind.execute(query)
