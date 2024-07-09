import os 
import argparse 
import re 
import shutil 
import logging 
import pymysql

# Parse the database url and extract user, host, port, database 
def parse_database_url(db_url):
    """
    Parses a MySQL database URL and extracts the user, host, port, and database name.

    Args:
    - db_url (str): The MySQL database URL in the format "mysql://user@host:port/database".

    Returns:
    - tuple: A tuple containing the following elements:
        - user (str): The username extracted from the URL.
        - host (str): The hostname or IP address extracted from the URL.
        - port (int): The port number extracted from the URL.
        - database (str): The database name extracted from the URL.

    Raises:
    - ValueError: If the database URL does not match the expected format.

    Example:
    >>> parse_database_url("mysql://user@localhost:3306/my_database")
    ('user', 'localhost', 3306, 'my_database')

    The function uses a regular expression to extract the components of the URL. 
    The expected format is 'mysql://user@host:port/database'.
    If the URL does not match this format, a ValueError is raised.
    """

    # Regex pattern to extract the hostname and port from the URL
    pattern = r'mysql:\/\/(?P<user>[^@]+)@(?P<host>[a-zA-Z0-9.-]+):(?P<port>\d+)\/(?P<database>[a-zA-Z0-9_]+)'
    match = re.search(pattern, db_url)
    if match:
        user = match.group('user')
        host = match.group('host')
        port = int(match.group('port'))  # Convert port to integer
        database = match.group('database')
        return user, host, port, database
    else:
        raise ValueError("Invalid database URL format")

def mysql_connection(query, host, database, port, user):
    """
    Executes a given SQL query on a MySQL database and fetches the result.

    This function establishes a connection to the MySQL database using provided connection details.
    It then executes the given query using a cursor obtained from the connection. After executing the query,
    it fetches all the rows of the query result and returns them. The function handles any errors that might
    occur during the process and ensures that the database connection is closed before returning the result.

    Args:
        query (str): The SQL query to be executed.
        database (str): The name of the database to connect to.
        host (str): The host name or IP address of the MySQL server.
        port (int): The port number to use for the connection.
        user (str): The username to use for the database connection.

    Returns:
        tuple: A tuple of tuples containing the rows returned by the query execution.

    Note:
        This function does not handle database password authentication. Ensure that the provided user
        has the necessary permissions and that the database is configured to allow password-less connections
        from the given host.
    """
    try:
        conn = pymysql.connect(
            host=host, user=user, port=port, database=database.strip()
        )
        cursor = conn.cursor()
        cursor.execute(query)
        info = cursor.fetchall()
    except pymysql.Error as err:
        logging.error(f"MySQL Error: {err}")
    cursor.close()
    conn.close()
    try: 
        return info
    except UnboundLocalError:
        logging.error(f"\nNothing returned for SQL query: {query}\n")
        sys.exit()

def get_unique_collections(result_tuples):
    """
    Extracts and returns a sorted list of unique collection names from a list of tuples.

    This function processes a list of tuples where each tuple contains a collection name as its first element.
    If the collection name starts with the prefix 'collection-', this prefix is removed before adding the name
    to a set to ensure uniqueness. Finally, the unique collection names are returned as a sorted list.

    Args:
    - result_tuples (list of tuples): A list of tuples, each containing collection names as their first element.

    Returns:
    - list: A sorted list of unique collection names with the 'collection-' prefix removed if present.

    Example:
    >>> get_unique_collections([('collection-abc',), ('collection-xyz',), ('abc',), ('collection-abc',)])
    ['abc', 'xyz']
    
    The function uses a set to ensure uniqueness of the collection names. It then converts the set to a sorted list
    before returning it.
    """
    unique_strings = set()  # Using a set to store unique strings

    for item in result_tuples:
        collection = item[0]
        if collection.startswith('collection-'):
            collection = collection[len('collection-'):]
        unique_strings.add(collection)
    
    return sorted(unique_strings)  # Convert the set to a list if needed


def get_info_from_master_db(db_url, query):
    """
    Fetches and returns unique collection names from a master database based on a given SQL query.

    This function connects to a MySQL database using the provided database URL and executes the given SQL query.
    It then processes the query result to extract and return a sorted list of unique collection names.

    Args:
    - db_url (str): The database URL in the format 'mysql://<user>@<host>:<port>/<database>'.
    - query (str): The SQL query to be executed on the database.

    Returns:
    - list: A sorted list of unique collection names.

    Example:
    >>> db_url = "mysql://user@localhost:3306/database"
    >>> query = "SELECT DISTINCT collection_name FROM collections"
    >>> get_info_from_master_db(db_url, query)
    ['collection1', 'collection2', 'collection3']
    
    The function performs the following steps:
    1. Parses the database URL to extract the user, host, port, and database name.
    2. Connects to the MySQL database and executes the given SQL query.
    3. Processes the query result to extract unique collection names.
    4. Returns the unique collection names as a sorted list.
    """
    user, host, port, database = parse_database_url(db_url)
    sql = mysql_connection(query, host, database, port, user)
    result = get_unique_collections(sql)
    return result


def cleanup_homology_dumps(homology_dumps_dir, before_release, dry_run, log_file=None):
    """
    Cleans up all homology dump directories before a user specified release number and the collection, 
    division information is obtained from the user defined master database url.

    Args:
    - homology_dumps_dir (str): Root directory of homology dumps to be cleaned up.
    - before_release (int): Ensembl release cutoff; directories with numeric names less than this value will be removed.
    - dry_run (bool): If True, performs a dry run without actually deleting directories.
    - log_file (str, optional): Optional filename for logging cleanup activities. If provided, logs will be written to this file.

    Returns:
    - None

    This function iterates through the directory structure under homology_dumps_dir.
    It identifies directories based on specific criteria (e.g., division name, collection name, numeric directory names).
    If dry_run is False, it attempts to delete identified directories.
    Logs are generated for each step, including directories found, checked, and removed or planned for removal in dry run mode.
    If no directories meet the removal criteria and dry_run is False, logs indicate no directories were found for removal.
    """
    if log_file:
        logging.basicConfig(filename=log_file, level=logging.INFO, format='%(asctime)s - %(message)s')
    dirs_removed = False

    with os.scandir(homology_dumps_dir) as dump_dir:
        for i in dump_dir:
            if i.is_dir() and i.name == div_info[1]:
                div_path = os.path.join(homology_dumps_dir, i.name)

                with os.scandir(div_path) as div_dir:
                    for j in div_dir:
                        if j.is_dir() and j.name in collections:
                            collection_path = os.path.join(div_path, j.name)
                            #logging.info(f"Found collection directory: {collection_path}")

                            with os.scandir(collection_path) as coll_path:
                                for k in coll_path:
                                    if k.is_dir() and k.name.isdigit() and int(k.name) < before_release:
                                        dirs_to_remove = os.path.join(collection_path, k.name)
                                        #logging.info(f"Checking directory: {dirs_to_remove}")
                                        if not dry_run:
                                            try:
                                                logging.info(f"Removed directory: {dirs_to_remove}")
                                                shutil.rmtree(dirs_to_remove)
                                                dirs_removed = True
                                            except Exception as err:
                                                logging.error(f"Error removing directory: {dirs_to_remove}: {err}")
                                                raise         
                                        else:
                                            logging.info(f"Dry run mode: Would have removed directory: {dirs_to_remove}")
                            
                            if not dirs_removed and not dry_run:
                                logging.info("No directories found for removal based on the specified criteria.")

          
def main():
    """
    Entry point for the homology dumps cleanup script.

    This function performs the following tasks:
    1. Parses command-line arguments to get the homology dumps directory, master database URL, 
       release cutoff, dry run option, and log file path.
    2. Configures logging based on the provided log file path, if any.
    3. Retrieves collections and division information from the master database using the provided URL.
    4. Calls the cleanup_homology_dumps function to perform the cleanup based on the parsed arguments.

    Command-line Arguments:
        --homology_dumps_dir (str): The root directory of the homology dumps. Required.
        --master_db_url (str): The URL of the master database. Optional.
        --before_release (int): The Ensembl release cutoff for cleanup (non-inclusive). Required.
        --dry_run: Perform a dry run without deleting files. Optional.
        --log (str): Optional log file to record deleted files.

    Returns:
        None
    """
    # Create the parser
    parser = argparse.ArgumentParser(description='Homology dumps cleanup script')

    parser.add_argument('--homology_dumps_dir', type=str, required=True, help='Root directory of the homology dumps.')
    parser.add_argument('--master_db_url', type=str, required=False, help='URL of the master database.')
    parser.add_argument('--before_release', type=int, required=True, help='Ensembl release cutoff for cleanup (non-inclusive).')
    parser.add_argument('--dry_run', action='store_true', help='Perform a dry run without deleting files.')
    parser.add_argument('--log', type=str, help='Optional log file to record deleted files.')

    args = parser.parse_args()
    logging.basicConfig(filename=args.log, level=logging.INFO, format='%(asctime)s - %(message)s')

    # Get collections and division info from master database
    global collections, div_info

    #Update this query to set a cutoff release before which collections should be ignored
    #Update this query to have a placeholder for current_release where it is 113
    collections_query = "SELECT DISTINCT ssh.name " \
                        "FROM method_link_species_set mlss " \
                        "JOIN method_link ml USING(method_link_id) " \
                        "JOIN species_set_header ssh USING(species_set_id) " \
                        "WHERE ml.type IN ('PROTEIN_TREES', 'NC_TREES') " \
                        "AND mlss.first_release IS NOT NULL " \
                        "AND mlss.first_release <= 113;"

    div_rel_query = "SELECT meta_value " \
                    "FROM meta " \
                    "WHERE meta_key IN ('division', 'schema_version');"

    collections = get_info_from_master_db(args.master_db_url, collections_query)
    div_info = get_info_from_master_db(args.master_db_url, div_rel_query)

    #Perform cleanup
    cleanup_homology_dumps(args.homology_dumps_dir, args.before_release, args.dry_run, args.log)

if __name__ == '__main__':
    main()

