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

Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtReleaseVersion

=head1 DESCRIPTION

This RunnableDB loads the current version number of UniProt and stores it as an mlss_tag

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::LoadUniProtReleaseVersion;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $tmp_file = $self->worker_temp_directory."/version.txt";
    my $command  = ['wget', '-O', $tmp_file, $self->param_required('uniprot_rel_url')];

    $self->param('output_file', $tmp_file);
    $self->param('cmd', $command);
}


sub write_output {
    my $self = shift @_;

    $self->SUPER::write_output();

    my $uniprot_version_data = $self->_slurp($self->param('output_file'));

    my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlssa->fetch_by_dbID($self->param_required('mlss_id'));
    $mlss->store_tag('uniprot_version', $uniprot_version_data);
}

1;

