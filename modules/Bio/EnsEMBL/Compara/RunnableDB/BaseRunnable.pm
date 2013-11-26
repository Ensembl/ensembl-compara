=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 SYNOPSIS

        # from within a Compara Runnable:
    my $FamilyAdaptor = $self->compara_dba()->get_FamilyAdaptor();

    my $ExternalFooFeatureAdaptor = $self->compara_dba($self->param('external_source'))->get_FooFeatureAdaptor();

=head1 DESCRIPTION

All Compara RunnableDBs *should* inherit from this module in order to work with module parameters and compara_dba in a neat way.

It inherits the parameter parsing functionality from Bio::EnsEMBL::Hive::Process
and provides a convenience method for creating the compara_dba from almost anything that can provide connection parameters.

Please refer to Bio::EnsEMBL::Hive::Process documentation to understand the basics of the RunnableDB interface.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable;

use strict;
use Carp;
use Bio::EnsEMBL::Hive::Utils ('stringify');
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;    # to use go_figure_compara_dba() and other things

use base ('Bio::EnsEMBL::Hive::Process');


=head2 compara_dba

    Description: this is an intelligent setter/getter of a Compara DBA. Resorts to magic in order to figure out how to connect.

    Example 1:   my $family_adaptor = $self->compara_dba()->get_FamilyAdaptor();    # implicit initialization and hashing

    Example 2:   my $external_foo_adaptor = $self->compara_dba( $self->param('db_conn') )->get_FooAdaptor();    # explicit initialization and hashing

=cut

sub compara_dba {
    my $self = shift @_;

    my $given_compara_db = shift @_ || ($self->param_is_defined('compara_db') ? $self->param('compara_db') : $self);
    my $given_ref = ref( $given_compara_db );
    my $given_signature  = ($given_ref eq 'ARRAY' or $given_ref eq 'HASH') ? stringify ( $given_compara_db ) : "$given_compara_db";

    if( !$self->{'_cached_compara_db_signature'} or ($self->{'_cached_compara_db_signature'} ne $given_signature) ) {
        $self->{'_cached_compara_db_signature'} = $given_signature;
        $self->{'_cached_compara_dba'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $given_compara_db );
    }

    return $self->{'_cached_compara_dba'};
}



=head2 get_species_tree_file

Returns the name of a file containing the species tree to be used.
 1. param('species_tree_file') if exists
 2. dumps param('species_tree_string') if exists
 3. dumps the 'species_tree' tag for the mlss param('mlss_id')

By default, it creates a file named 'spec_tax.nh' in the worker temp directory

=cut

sub get_species_tree_file {
    my $self = shift @_;

    unless( $self->param('species_tree_file') ) {

        $self->load_species_tree_from_db unless $self->param('species_tree_string');

        my $species_tree_string = $self->param('species_tree_string');
        eval {
            use Bio::EnsEMBL::Compara::Graph::NewickParser;
            my $eval_species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string);
            my @leaves = @{$eval_species_tree->get_all_leaves};
        };
        if($@) {
            die "Error '$@' parsing species tree from the string '$species_tree_string'";
        }

            # store the string in a local file:
        my $file_basename = shift || 'spec_tax.nh';
        my $species_tree_file = $self->worker_temp_directory . $file_basename;
        open SPECIESTREE, ">$species_tree_file" or die "Could not open '$species_tree_file' for writing : $!";
        print SPECIESTREE $species_tree_string;
        close SPECIESTREE;
        $self->param('species_tree_file', $species_tree_file);
    }
    return $self->param('species_tree_file');
}

sub load_species_tree_from_db {
    my ($self) = @_;

    my $mlss_id = $self->param_required('mlss_id');
    my $label = $self->param('label') || 'default';
    my $species_tree_string = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($mlss_id, $label)->species_tree();
    $self->param('species_tree_string', $species_tree_string);
}

=head2 get_species_tree_string

Return a string containing the species tree to be used
 1. param('species_tree_string') if exists
 2. content from param('species_tree_file') if exists
 3. 'species_tree' tag for the mlss param('mlss_id')

=cut

sub get_species_tree_string {
    my $self = shift @_;

    unless( $self->param('species_tree_string') ) {
        if( my $species_tree_file = $self->param('species_tree_file') ) {
            $self->param('species_tree_string', $self->_slurp( $species_tree_file ));
        } else {
            $self->load_species_tree_from_db;
        }
    }
    return  $self->param('species_tree_string');
}


=head2 _slurp

Reads the whole content of a file and returns it as a string

=cut

sub _slurp {
  my ($self, $file_name) = @_;
  my $slurped;
  {
    local $/ = undef;
    open(my $fh, '<', $file_name) or $self->throw("Couldnt open file [$file_name]");
    $slurped = <$fh>;
    close($fh);
  }
  return $slurped;
}




1;
