=head1 LICENSE

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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MoreAppropriateCollectionToQuery

=head1 DESCRIPTION

Runnable to parse the record of query genomes to check and pass on
for potential update with new taxonomic based reference comparison

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MoreAppropriateCollectionToQuery;

use warnings;
use strict;
use List::MoreUtils qw/ uniq /;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'queries_to_update_file'  => 'queries_to_update.txt',
    };
}

sub fetch_input {
    my $self = shift;

    my $record_dir  = $self->param_required("species_set_record");
    my $ignore_file = $self->param("queries_to_update_file");
    my @records     = glob "${record_dir}/*/*.txt";
    my @queries;
    my @ignore_list;

    if ( $self->param("queries_to_update_file") ) {
        @ignore_list = split( /\n/, $self->_slurp( $self->param("queries_to_update_file") ) );
    }

    foreach my $file ( @records ) {
        my $contents = $self->_slurp( $file );
        push @queries, ( split( /\n/, $contents ) );
    }

    my @query_list = uniq( @queries );
    my %all_queries;
    @all_queries{ @ignore_list } = ();
    my @reduced_queries = ( grep ! exists $all_queries{$_}, @query_list );

    my $ss_adap = $self->compara_dba->get_SpeciesSetAdaptor;
    my $collections = $ss_adap->fetch_all_current_collections;

    my @collection_names = map { $_->name() } @{ $collections };
    my @taxons = grep { $_ !~ /shared|default|references/ } @collection_names;
    s/^collection-//g for @taxons;

    my @new_taxa = map { $_->is_current ? $_->name() : () } @{ $collections };
    my @new_collection_taxons = grep { $_ !~ /shared|default|references/ } @new_taxa;
    s/^collection-//g for @new_collection_taxons;

    $self->param('check_for_update_queries', \@reduced_queries);
    $self->param('taxon_list', \@taxons);
    $self->param('new_taxons', \@new_collection_taxons);
}

sub run {
    my $self = shift;

    my @update_list;
    my @reduced_queries          = @{ $self->param('check_for_update_queries') };
    my $get_nearest_taxonomy_exe =  $self->param_required("get_nearest_taxonomy_exe");
    unless ($self->compara_dba->dbc->isa('Bio::EnsEMBL::Hive::DBSQL::DBConnection')) {
        bless $self->compara_dba->dbc, 'Bio::EnsEMBL::Hive::DBSQL::DBConnection';
    }
    my $url        = $self->compara_dba->dbc->url();
    my $taxon_list = join( " ", @{ $self->param("taxon_list") } );
    $taxon_list =~ s/\n//g;

    foreach my $query ( @reduced_queries ) {
        my $cmd = "python $get_nearest_taxonomy_exe --taxon_name $query --url $url --taxon_list " .
            join( " ", @{ $self->param("taxon_list") } );
        my $appropriate_taxon = $self->get_command_output($cmd, { die_on_failure => 1 });
        push @update_list, $query if ( grep( $appropriate_taxon, @{ $self->param('new_taxons') } ) );
    }

    $self->param('update_species', \@update_list);
}

sub write_output {
    my $self = shift;

    my $queries_to_update = $self->param('update_species');
    my $out_file          = $self->param("queries_to_update_file");
    $self->_spurt( $out_file, "\n" . join( "\n", @{ $queries_to_update } ), 1 );
    $self->dataflow_output_id( { 'queries_to_update' => $queries_to_update }, 1);

}

1;
