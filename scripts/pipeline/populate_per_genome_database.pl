#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use warnings;
use strict;

=head1 NAME

populate_per_genome_database.pl

=head1 DESCRIPTION

Copies the genome_name species-related data in the given tables from the
pipeline db to the given compara db. It will also copy all the information in
"ncbi_taxa_node" and "ncbi_taxa_name" tables.

=head1 SYNOPSIS

perl populate_per_genome_database.pl --help

perl populate_per_genome_database.pl
    --pipeline_db pipeline_db_url
    --compara_db per_species_db_url
    --tables "genome_db,method_link_species_set_id..."

=head1 REQUIREMENTS

This script uses mysql, mysqldump and mysqlimport programs.
It requires at least version 4.1.12 of mysqldump as it uses
the --replace option.

=head1 ARGUMENTS

=over

=item B<[--help]>

Prints help message and exits.

=item B<--pipeline_db pipeline_db_url>

The pipeline database url.
The URL format is:
mysql://username[:passwd]@host[:port]/db_name

=item B<--compara_db per_species_db_url>

The per-species compara database url.
The URL format is:
mysql://username[:passwd]@host[:port]/db_name

=item B<--tables list_of_tables>

List of tables to copy. Can take several values or a string of comma-separated values.
E.g. --tables genome_db,homology,homology_member

=item B<--genome_name genome_name>

Optional. The genome_name as used in database.
E.g. --genome_name homo_sapiens

=item B<--copy_dna>

Optional. Flag to copy dna. By default, dna will not be copied.

=back

=cut

use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);

my ( $help, $pipeline_db, $compara_db, @list_of_tables, $genome_name, $dnafrag );
GetOptions(
    "help"          => \$help,
    "pipeline_db=s" => \$pipeline_db,
    "compara_db=s"  => \$compara_db,
    "tables=s"      => \@list_of_tables,
    "genome_name=s" => \$genome_name,
    "copy_dna"      => \$dnafrag,
);

@list_of_tables = split( /,/, join( ',', @list_of_tables ) );
my %tables      =  map { $_ => 1 } @list_of_tables;

my $pipeline_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $pipeline_db );
my $compara_dba  = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db );

# Copy ncbi tables
copy_table( $pipeline_dba->dbc, $compara_dba->dbc, "ncbi_taxa_node", 1 );
copy_table( $pipeline_dba->dbc, $compara_dba->dbc, "ncbi_taxa_name", 1 );

# Collect necessary genome_name as provided or from db
$genome_name = $genome_name ? $genome_name : ( $compara_dba->dbc->dbname =~ /([a-z0-9_])_compara_/i );
my $genome_db = $pipeline_dba->get_GenomeDBAdaptor->fetch_by_name_assembly( $genome_name );

$compara_dba->dbc->do("SET FOREIGN_KEY_CHECKS = 0");

if ( defined $tables{'genome_db'} ) {
    copy_genome_db( $compara_dba, $genome_db );
}

if ( defined $tables{'method_link_species_set'} or defined $tables{'species_set'} ) {
    copy_mlss_and_ss( $pipeline_dba, $compara_dba, $genome_db );
}

if ( defined $tables{'gene_member'} or defined $tables{'seq_member'} ) {
    copy_gene_and_seq_members( $pipeline_dba, $compara_dba, $genome_db->dbID );
    # For rapid release as of e103-e104 only canonical peptides are used -
    # when pairwise alignments are introduced, dnafrags will also need to be copied
    if ( $dnafrag ) {
        copy_dnafrags( $pipeline_dba, $compara_dba, $genome_db->dbID );
    }
}

if ( defined $tables{'peptide_align_feature'} ) {
    copy_pafs( $pipeline_dba, $compara_dba, $genome_db->dbID );
}

if ( defined $tables{'homology'} or defined $tables{'homology_member'} ) {
    copy_homology_and_members( $pipeline_dba, $compara_dba, $genome_db );
}

$compara_dba->dbc->do("SET FOREIGN_KEY_CHECKS = 1");


exit(0);

=head2 copy_genome_db

    Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba (Mandatory)
    Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor $genome_db (Mandatory)
    Description : copy from $from_dba to $to_dba just the genome_db which
                  correspond to $genome_db only.
    Returns     : None
    Exceptions  : None

=cut

sub copy_genome_db {
    my ($to_dba, $genome_db) = @_;

    my $genome_dba = $to_dba->get_GenomeDBAdaptor;
    $genome_dba->store( $genome_db );
}

=head2 copy_mlss_and_ss

    Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba (Mandatory)
    Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba (Mandatory)
    Arg[3]      : Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor $genome_db (Mandatory)
    Description : copy from $from_dba to $to_dba just the method_link_species_set
                  and species_sets which correspond to $genome_db_id only.
    Returns     : None
    Exceptions  : None

=cut

sub copy_mlss_and_ss {
    my ($from_dba, $to_dba, $genome_db) = @_;

    my $from_mlss_adap = $from_dba->get_MethodLinkSpeciesSetAdaptor;
    my $to_mlss_adap   = $to_dba->get_MethodLinkSpeciesSetAdaptor;

    my $mlsss = $from_mlss_adap->fetch_all_by_GenomeDB( $genome_db );
    foreach my $mlss ( @$mlsss ) {
        $to_mlss_adap->store( $mlss );
    }
}

=head2 copy_gene_and_seq_members

    Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba (Mandatory)
    Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba (Mandatory)
    Arg[3]      : $genome_db_id (Mandatory)
    Description : copy from $from_dba to $to_dba just the gene_member and
                  seq_members which correspond to $genome_db_id only.
    Returns     : None
    Exceptions  : None

=cut

sub copy_gene_and_seq_members {
    my ($from_dba, $to_dba, $genome_db_id) = @_;

    my $constraint = "genome_db_id = $genome_db_id";
    copy_table( $from_dba->dbc, $to_dba->dbc, 'gene_member', $constraint, 1 );
    copy_table( $from_dba->dbc, $to_dba->dbc, 'seq_member', $constraint, 1 );
    copy_data( $from_dba->dbc, $to_dba->dbc, 'sequence', "SELECT sequence.* FROM sequence JOIN seq_member USING (sequence_id) WHERE $constraint", 1 );
}

=head2 copy_pafs

    Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba (Mandatory)
    Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba (Mandatory)
    Arg[3]      : $genome_db_id (Mandatory)
    Description : copy from $from_dba to $to_dba just the peptide_align_features
                  which correspond to $genome_db_id only.
    Returns     : None
    Exceptions  : None

=cut

sub copy_pafs {
    my ($from_dba, $to_dba, $genome_db_id) = @_;

    my $constraint = "hgenome_db_id = $genome_db_id OR qgenome_db_id = $genome_db_id";

    copy_table( $from_dba->dbc, $to_dba->dbc, 'peptide_align_feature', $constraint, 1 );
}

=head2 copy_homology_and_members

    Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba (Mandatory)
    Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba (Mandatory)
    Arg[3]      : Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor $genome_db (Mandatory)
    Description : copy from $from_dba to $to_dba just the homology and homology_members
                  which correspond to $genome_db_id only.
    Returns     : None
    Exceptions  : None

=cut

sub copy_homology_and_members {
    my ($from_dba, $to_dba, $genome_db) = @_;

    my $from_mlss_adap = $from_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlsss          = $from_mlss_adap->fetch_all_by_GenomeDB( $genome_db );

    foreach my $mlss ( @$mlsss ) {
        my $mlss_id = $mlss->dbID;
        my $constraint = "method_link_species_set_id = $mlss_id";
        copy_table( $from_dba->dbc, $to_dba->dbc, 'homology', $constraint, 1 );
        copy_data( $from_dba->dbc, $to_dba->dbc, 'homology_member', "SELECT homology_member.* FROM homology_member JOIN homology USING (homology_id) WHERE $constraint", 1 );
    }
}

=head2 copy_dnafrags

    Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
    Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
    Arg[3]      : $genome_db_id (Mandatory)
    Description : copy from $from_dba to $to_dba all the DnaFrags which
                  correspond to $genome_db_id only.
    Returns     : None
    Exceptions  : None

=cut

sub copy_dnafrags {
    my ($from_dba, $to_dba, $genome_db_id) = @_;

    my $constraint = "genome_db_id = $genome_db_id";
    copy_table( $from_dba->dbc, $to_dba->dbc, 'dnafrag', $constraint, 1 );
    copy_data( $from_dba->dbc, $to_dba->dbc, 'dnafrag_alt_region', "SELECT dnafrag_alt_region.* FROM dnafrag_alt_region JOIN dnafrag USING (dnafrag_id) WHERE $constraint", 1 );
}

1;
