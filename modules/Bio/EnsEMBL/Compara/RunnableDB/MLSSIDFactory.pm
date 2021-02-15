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
        'methods'   => {
            #'ENSEMBL_PARALOGUES'    => 2,
            #'ENSEMBL_ORTHOLOGUES'   => 3,
        },
        'batch_size' => 1,
    }
}

sub write_output {
    my $self = shift @_;

    my $mlss_a  = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $methods = $self->param_required('methods');

    foreach my $method (keys %$methods) {
        my $branch_number = $methods->{$method};
        my $mlsss = $mlss_a->fetch_all_by_method_link_type($method);

        if ( $self->param('line_count') ) {
            foreach my $mlss ( @$mlsss ) {
                my $line_count = $self->_get_line_count($mlss);
                $self->dataflow_output_id( { 'mlss_id' => $mlss->dbID, 'exp_line_count' => $line_count }, $branch_number);
            }
        }
        else {
            my @batch = ();
            foreach my $mlss (@$mlsss) {
                if ( $self->param('batch_size') == 1 ) {
                    $self->dataflow_output_id( { 'mlss_id' => $mlss->dbID }, $branch_number);
                } else {
                    if ( scalar @batch == $self->param('batch_size') ) {
                        $self->dataflow_output_id( {'mlss_ids' => \@batch}, $branch_number );
                        @batch = ($mlss->dbID);
                    } else {
                        push @batch, $mlss->dbID;
                    }
                }
            }
            # flow the last batch
            $self->dataflow_output_id( {'mlss_ids' => \@batch}, $branch_number ) if scalar @batch;
        }
    }
}

sub _get_line_count {
    my ($self, $mlss) = @_;
    my $adaptor;

    if ($mlss->method->class =~ /homology/i) {
        $adaptor = $self->compara_dba->get_HomologyAdaptor;
    }
    elsif ($mlss->method->class =~ /synteny/i) {
        $adaptor = $self->compara_dba->get_SyntenyRegionAdaptor;
    }
    else {
        die "_get_line_count does not support method: " . $mlss->method->type;
    }
    my $line_count = $adaptor->count_by_mlss_id($mlss->dbID);
    return $line_count;
}
1;
