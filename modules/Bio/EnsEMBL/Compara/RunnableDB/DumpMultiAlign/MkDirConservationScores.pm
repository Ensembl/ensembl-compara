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

Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MkDirConservationScores

=head1 SYNOPSIS

Find the best directory name to dump some conservation scores, and creates it

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MkDirConservationScores;

use strict;
use warnings;

use File::Path qw(make_path remove_tree);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub write_output {
    my $self = shift;

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param_required('mlss_id'));

    my $dirname = $mlss->name;
    if ($mlss->name =~ /^Gerp Conservation Scores \((.*)\)$/) {
        $dirname = $1.".gerp_conservation_scores";
    }
    $dirname =~ s/[\W\s]+/_/g;
    $dirname =~ s/_$//;

    my $output_dir = $self->param_required('export_dir').'/'.$dirname;
    remove_tree($output_dir);
    make_path($output_dir);

    $self->dataflow_output_id( {'dirname' => $dirname} );
}

1;
