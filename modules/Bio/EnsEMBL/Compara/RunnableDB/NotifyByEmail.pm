=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::NotifyByEmail

=head1 DESCRIPTION

Simple version of eHive's NotifyByEmail that pulls the pipeline name in #pipeline_name#

=head1 CONTACT

Please email comments or questions to the public Ensembl developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at <http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::NotifyByEmail;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },
        subject => 'Automatic message from #pipeline_name#',
    }
}


sub fetch_input {
    my $self = shift @_;

    if ($self->db) {
        $self->param('pipeline_name', $self->input_job->hive_pipeline->display_name);
    } else {
        my $name = ref($self);
        $name =~ /^(.*)=/;
        $self->param('pipeline_name', "Standalone run of ". ($1 || $name));
    }
}


1;
