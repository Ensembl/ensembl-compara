import argparse
import csv
from sqlalchemy import create_engine, text

def execute_query(connection, query):
    """
    Execute a SQL query and return the result.

    Args:
        connection: The database connection object.
        query: The SQL query to execute.

    Returns:
        The result of the executed query.
    """
    return connection.execute(text(query))

def get_lastz_mlss_from_release_db(release):
    """
    Generate the SQL query to retrieve method_link_species_set_ids from the release database.

    Args:
        release: The release version.

    Returns:
        The SQL query string.
    """
    return f"""
    SELECT 
        method_link_species_set_tag.`method_link_species_set_id`
    FROM 
        method_link_species_set_tag 
    INNER JOIN
        method_link_species_set
    ON 
        method_link_species_set_tag.method_link_species_set_id = method_link_species_set.method_link_species_set_id
    WHERE 
        (method_link_species_set_tag.tag IN ('reference_species', 'ref_genome_coverage', 'ref_genome_length', 
          'non_reference_species', 'non_ref_genome_coverage', 'non_ref_genome_length') 
        AND 
        method_link_species_set.first_release={release})
    OR
        method_link_species_set_tag.tag IN ('rerun_in_{release}','patched_in_{release}') 
    AND 
        method_link_species_set.method_link_id = 16;
    """

def get_mlss_from_lastz_db():
    """
    Generate the SQL query to retrieve distinct method_link_species_set_ids from the lastz database.

    Returns:
        The SQL query string.
    """
    return """
    SELECT DISTINCT method_link_species_set_id FROM method_link_species_set_tag 
    WHERE tag IN ('reference_species','ref_genome_coverage', 'ref_genome_length', 
                  'non_reference_species', 'non_ref_genome_coverage', 'non_ref_genome_length');
    """

def get_result_query(ids_str):
    """
    Generate the SQL query to retrieve coverage ratios for the given method_link_species_set_ids.

    Args:
        ids_str: A comma-separated string of method_link_species_set_ids.

    Returns:
        The SQL query string.
    """
    return f"""
    SELECT 
        mlss,
        reference_species,
        ref_genome_coverage / ref_genome_length AS ref_coverage_ratio,
        non_reference_species,
        non_ref_genome_coverage / non_ref_genome_length AS non_ref_coverage_ratio
    FROM (
        SELECT 
            method_link_species_set_id AS mlss,
            (SELECT value FROM method_link_species_set_tag WHERE method_link_species_set_id = mlss 
             AND tag = 'reference_species') AS reference_species,
            (SELECT value FROM method_link_species_set_tag WHERE method_link_species_set_id = mlss 
             AND tag = 'ref_genome_coverage') AS ref_genome_coverage,
            (SELECT value FROM method_link_species_set_tag WHERE method_link_species_set_id = mlss 
             AND tag = 'ref_genome_length') AS ref_genome_length,
            (SELECT value FROM method_link_species_set_tag WHERE method_link_species_set_id = mlss 
             AND tag = 'non_reference_species') AS non_reference_species,
            (SELECT value FROM method_link_species_set_tag WHERE method_link_species_set_id = mlss 
             AND tag = 'non_ref_genome_coverage') AS non_ref_genome_coverage,
            (SELECT value FROM method_link_species_set_tag WHERE method_link_species_set_id = mlss 
             AND tag = 'non_ref_genome_length') AS non_ref_genome_length               
        FROM 
            method_link_species_set_tag
        WHERE 
            method_link_species_set_id IN ({ids_str})
        GROUP BY 
            method_link_species_set_id
    ) AS subquery
    """

def write_to_tsv(filename, result):
    """
    Write the query result to a TSV file.

    Args:
        filename: The name of the TSV file.
        result: The query result to write.
    """
    with open(filename, 'w', newline='') as tsvfile:
        writer = csv.writer(tsvfile, delimiter='\t')
        writer.writerow(['mlss', 'reference_species', 'ref_coverage_ratio', 'non_reference_species', 
                         'non_ref_coverage_ratio'])
        for row in result:
            ref_coverage_ratio = row['ref_coverage_ratio']
            non_ref_coverage_ratio = row['non_ref_coverage_ratio']
            writer.writerow([
                row['mlss'], 
                row['reference_species'], 
                round((ref_coverage_ratio if ref_coverage_ratio is not None else 0) * 100, 4), 
                row['non_reference_species'], 
                round((non_ref_coverage_ratio if non_ref_coverage_ratio is not None else 0) * 100, 4)
            ])

def process_database(url, output_file, release=None):
    """
    Process the database to retrieve coverage ratios and write the result to a TSV file.

    Args:
        url: The database URL.
        output_file: The name of the output TSV file.
        release: The release version (optional).
    """
    engine = create_engine(url)
    with engine.connect() as connection:
        if release is None: 
            initial_query = get_mlss_from_lastz_db()
            initial_result = execute_query(connection, initial_query)
            ids = [row[0] for row in initial_result]

            if ids:
                ids_str = ', '.join(map(str, ids))
                result_query = get_result_query(ids_str)
                result = execute_query(connection, result_query)
                write_to_tsv(output_file, result)
        
        elif release is not None:
            initial_query = get_lastz_mlss_from_release_db(release)
            initial_result = execute_query(connection, initial_query)
            method_link_species_set_ids = [row[0] for row in initial_result]

            if method_link_species_set_ids:
                ids_str = ', '.join(map(str, method_link_species_set_ids))
                result_query = get_result_query(ids_str)
                result = execute_query(connection, result_query)
                write_to_tsv(output_file, result)

def main():
    """
    Main function to parse user input and process the database.
    """
    parser = argparse.ArgumentParser(description='Process database and write coverage ratios to TSV file.')
    parser.add_argument('url', type=str, help='The database URL.')
    parser.add_argument('output_file', type=str, help='The name of the output TSV file.')
    parser.add_argument('--release', type=int, default=None, help='The release version (optional).')
    args = parser.parse_args()

    process_database(args.url, args.output_file, args.release)

if __name__ == "__main__":
    main()