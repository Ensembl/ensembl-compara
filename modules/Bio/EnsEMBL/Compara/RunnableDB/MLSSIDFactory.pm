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

Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory

=head1 DESCRIPTION

Given a list of Methods and branch numbers, flows all the available MLSSs

=cut

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MLSSIDFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'registry'  => undef,   # In case the Compara DBA is not a URL
        'methods'   => {
            #'ENSEMBL_PARALOGUES'    => 2,
            #'ENSEMBL_ORTHOLOGUES'   => 3,
        },
    }
}

sub write_output {
    my $self = shift @_;

    if ($self->param("registry")) {
        $self->load_registry($self->param("registry"));
    }
    my $mlss_a  = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $methods = $self->param_required('methods');

    foreach my $method (keys %$methods) {
        my $branch_number = $methods->{$method};
        my $mlsss = $mlss_a->fetch_all_by_method_link_type($method);
        foreach my $mlss (@$mlsss) {
            $self->dataflow_output_id( { 'mlss_id' => $mlss->dbID }, $branch_number);
        }
    }
}

1;
