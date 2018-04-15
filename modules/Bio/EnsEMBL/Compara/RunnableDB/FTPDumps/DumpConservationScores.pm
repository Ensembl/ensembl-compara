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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::DumpConservationScores

=head1 SYNOPSIS

Wrapper around dump_features.pl to dump conservation scores, but for
a given list of regions given in the "chunkset" parameter.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::DumpConservationScores;

use strict;
use warnings;

use File::Basename;
use File::Path qw(make_path);

use Bio::EnsEMBL::Hive::Utils ('dir_revhash');

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },
        'this_bedgraph' => '#work_dir#/#hash_dir#/#name#.#chunkset_id#.bedgraph',
        'cmd'           => '#dump_features_program# --feature cs_#mlss_id# --compara_url #compara_url# --species #name# --regions "#regions_bed_file#" --reg_conf "#registry#" > #this_bedgraph#',
    }
}


sub fetch_input {
    my $self = shift;

    my $filename = $self->worker_temp_directory . "/regions.bed";
    open(my $fh, '>', $filename);
    foreach my $aref (@{$self->param_required('chunkset')}) {
        print $fh join("\t", $aref->[0], $aref->[1]-1, $aref->[2]), "\n";
    }
    close $fh;
    $self->param('regions_bed_file', $filename);

    $self->param('hash_dir', dir_revhash($self->param_required('chunkset_id')));

    make_path(dirname($self->param_required('this_bedgraph')));
}


1;
