=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MLSSJobFactory;

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MLSSJobFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'species_priority'  => [ 'homo_sapiens', 'gallus_gallus', 'oryzias_latipes' ],
    }
}

sub fetch_input {
    my ($self) = @_;

    $self->param('good_mlsss', []);

    # Get MethodLinkSpeciesSet adaptor:
    my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;

    if ($self->param('mlss_id')) {
        my $mlss = $mlssa->fetch_by_dbID($self->param('mlss_id')) ||
            die $self->param('mlss_id')." does not exist in the database !\n";
        $self->_test_and_add_mlss($mlss);
        return;
    }

    foreach my $ml_typ (split /[,:]/, $self->param_required('method_link_types')){
        # Get MethodLinkSpeciesSet Objects for required method_link_type
        my $mlss_listref = $mlssa->fetch_all_by_method_link_type($ml_typ);
        foreach my $mlss (@$mlss_listref) {
            $self->_test_and_add_mlss($mlss);
        }
    }
}

sub _test_and_add_mlss {
    my ($self, $mlss) = @_;

    my $mlss_id     = $mlss->dbID();

    if (($mlss->method->class eq 'GenomicAlignBlock.pairwise_alignment') or ($mlss->method->type eq 'EPO_LOW_COVERAGE')) {
        my $ref_species = $mlss->get_value_for_tag('reference_species');
        die "Reference species missing! Please check the 'reference species' tag in method_link_species_set_tag for mlss_id $mlss_id\n" unless $ref_species;

    } else {
        my %species_in_mlss = map {$_->name => 1} @{$mlss->species_set_obj->genome_dbs};
        my @ref_species_in = grep {$species_in_mlss{$_}} @{$self->param('species_priority')};
        if (not scalar(@ref_species_in)) {
            die "Could not find any of (".join(", ", map {'"'.$_.'"'} @{$self->param('species_priority')}).") in mlss_id $mlss_id. Edit the 'species_priority' list in MLSSJobFactory.\n";
        }
        $mlss->add_tag('reference_species', $ref_species_in[0]);
    }

    push @{$self->param('good_mlsss')}, $mlss;
}


sub write_output {
    my ($self)  = @_;

    foreach my $mlss (@{$self->param('good_mlsss')}) {
        $self->dataflow_output_id({'mlss_id' => $mlss->dbID, 'species' => $mlss->get_value_for_tag('reference_species')}, 2);
    }
}

1;

