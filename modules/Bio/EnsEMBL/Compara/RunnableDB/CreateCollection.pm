
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateCollection

=head1 DESCRIPTION

Used to create a new collection given a list of genome_db_ids.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CreateCollection;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    #Get genome_db_id list from the accumulator updated_genome_db_ids.
    my $genome_db_ids_list = $self->param('updated_genome_db_ids');
    
    #Holds a list of the genome_db_adaptors.
    my @genome_db_adaptors_list;

    #Get read-only master database adaptor.
    $self->param( 'master_dba', Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param_required('master_db_ro') ) ) || die "Could not get adaptor";

    #Get list of adaptors.
    foreach my $genome_db_id (@{$genome_db_ids_list}) {
        my $gdba = $self->param( 'master_dba')->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) || die "Could not fetch adaptor for $genome_db_id";
        push( @genome_db_adaptors_list, $gdba );
    }

    $self->param( 'genome_db_adaptors_list', \@genome_db_adaptors_list);
}

sub write_output {
    my $self = shift;

    my $all_gdbs = $self->param('genome_db_adaptors_list');

    #Need to get write access on the master database.
    $self->elevate_privileges($self->param('master_dba')->dbc);

    #Creates the new collection.
    $self->_write_ss( $all_gdbs, $self->param('new_collection_name') ) || die "Could not store collection: " . $self->param('new_collection_name');
}

# Write the species-set of the given genome_db_adaptors_list
# Try to reuse the data from the reference db if possible
sub _write_ss {
    my ( $self, $genome_db_adaptors_list, $name ) = @_;

    #use Data::Dumper;
    #print Dumper $genome_db_adaptors_list;
    my $ss = Bio::EnsEMBL::Compara::SpeciesSet->new( -GENOME_DBS => $genome_db_adaptors_list, -name => "collection-$name" );
    $self->param('master_dba')->get_SpeciesSetAdaptor->store($ss) || die "Could not store SS";

    return $ss;
}

1;

