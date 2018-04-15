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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ConcatenateFiles

=head1 SYNOPSIS

Generic runnable that can concatenate some files ("input_files" parameter)
into a new output file ("output_file" parameter).

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ConcatenateFiles;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::Process');


sub run {
    my $self = shift;

    my $output_file = $self->param_required('output_file');
    unlink $output_file;

    foreach my $input_file (@{$self->param_required('input_files')}) {
        die "Undefined input file" unless $input_file;
        $self->run_system_command("cat '$input_file' >> '$output_file'", { die_on_failure => 1 });
    }
}

1;
