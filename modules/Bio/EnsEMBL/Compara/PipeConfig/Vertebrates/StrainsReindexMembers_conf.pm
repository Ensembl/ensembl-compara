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

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsReindexMembers_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsReindexMembers_conf -host mysql-ens-compara-prod-X -port XXXX \
        -collection <collection> -member_type <protein|ncrna>

=head1 EXAMPLES

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsReindexMembers_conf -host mysql-ens-compara-prod-X -port XXXX ...

e99  # From now on the collection and member_type parameters are only used to name the database, mlss_id is not needed anymore
    -prev_tree_db murinae_ptrees_prev  -collection murinae -member_type protein
    -prev_tree_db murinae_nctrees_prev -collection murinae -member_type ncrna
    -prev_tree_db sus_ptrees_prev      -collection sus     -member_type protein
    -prev_tree_db sus_nctrees_prev     -collection sus     -member_type ncrna

e98 protein-trees
    -mlss_id 40128 -member_type ncrna   -prev_rel_db murinae_nctrees_prev $(mysql-ens-compara-prod-7-ensadmin details hive)
e98 ncRNA-trees
    -mlss_id 40126 -member_type protein -prev_rel_db murinae_ptrees_prev  $(mysql-ens-compara-prod-7-ensadmin details hive)

=head1 DESCRIPTION

A specialized version of ReindexMembers pipeline to use in Vertebrates for
strains/breeds, e.g. murinae or sus.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::StrainsReindexMembers_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ReindexMembers_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'division'      => 'vertebrates',

        'prev_tree_db' => $self->o('collection') . '#expr( (#member_type# eq "protein") ? "_ptrees_prev" : "_nctrees_prev" )expr#',
    };
}

sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    # Block unguarded funnel analyses; to be unblocked as needed during pipeline execution.
    my @unguarded_funnel_analyses = (
        'reindex_member_ids',
        'datacheck_funnel',
    );
    foreach my $logic_name (@unguarded_funnel_analyses) {
        $analyses_by_name->{$logic_name}->{'-analysis_capacity'} = 0;
    }
}

1;
