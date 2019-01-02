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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::FTPDumps::ConcatenateBedGraphFiles

=head1 SYNOPSIS

This Runnable concatenates as many bedGraph files as requested into one.
It takes care of removing the track headers from the second file onwards.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ConcatenateBedGraphFiles;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::Process');


sub run {
    my $self = shift;

    my $output_file = $self->param_required('bedgraph_file');
    unlink $output_file;

    # for some reason, all_bedgraph_files can contain undefs - filter them out
    my @all_bedgraph_files = grep { defined $_ } @{$self->param_required('all_bedgraph_files')};

    $self->run_system_command(['cp', shift @all_bedgraph_files, $output_file], { die_on_failure => 1 });

    foreach my $input_file ( @all_bedgraph_files ) {
        $self->run_system_command("tail -n+2 '$input_file' >> '$output_file'", { die_on_failure => 1 });
    }
}

1;
