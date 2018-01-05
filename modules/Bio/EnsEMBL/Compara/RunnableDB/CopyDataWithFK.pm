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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 SYNOPSIS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CopyDataWithFK;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Scalar qw(wrap_array);
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:row_copy);

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults(@_) },

        'do_transactions'       => 1,

        'expand_tables'         => 1,

        'rfam_model_id'         => undef,
        'family_stable_id'      => undef,
        'protein_tree_stable_id'        => undef,
        'method_link_species_set_id'    => undef,

        'foreign_keys_db'       => undef,   # can be undef if $self->compara_dba is InnoDB and has foreign keys
    };
}

sub fetch_input {
    my $self = shift @_;

    if ($self->param('foreign_keys_db')) {
        my $foreign_keys_db = $self->get_cached_compara_dba('foreign_keys_db')
                                || die "Could not get foreign_keys_db: " . $self->param('foreign_keys_db');
        $self->param('foreign_keys_db', $foreign_keys_db->dbc);
    }

    $self->param('copy_args', []);
    # Here we declare a number of entry points (e.g.  "protein_tree_stable_id") and the rows they will copy
    $self->_expand_array('protein_tree_stable_id', 'gene_tree_root', 'stable_id');
    $self->_expand_array('rfam_model_id', 'gene_tree_root_tag', 'tag = "model_id" AND value');
    $self->_expand_array('family_stable_id', 'family', 'stable_id');
    $self->_expand_array('method_link_species_set_id', 'method_link_species_set', 'method_link_species_set_id');
}

# Here we allow each entry point to be reused several times
sub _expand_array {
    my ($self, $param_name, $table, $where_field) = @_;
    foreach my $value (@{wrap_array($self->param($param_name))}) {
        push @{$self->param('copy_args')}, [$table, $where_field, $value];
    }
}

sub write_output {
    my $self = shift @_;
    $self->call_within_transaction( sub {
        foreach my $a (@{$self->param('copy_args')}) {
            copy_data_with_foreign_keys_by_constraint($self->data_dbc, $self->compara_dba->dbc, @$a, $self->param('foreign_keys_db'), $self->param('expand_tables'));
            $self->warning(sprintf('Copied the data recursively for %s WHERE %s = "%s"', @$a));
        }
    } );
}

1;
 
