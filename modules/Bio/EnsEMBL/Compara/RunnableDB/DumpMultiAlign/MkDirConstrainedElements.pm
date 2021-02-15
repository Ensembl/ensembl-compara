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

Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MkDirConstrainedElements

=head1 SYNOPSIS

Find the best directory name to dump some constrained elements, and creates it

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MkDirConstrainedElements;

use strict;
use warnings;

use File::Path qw(make_path remove_tree);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub write_output {
    my $self = shift;

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param_required('mlss_id'));

    my $dirname = $mlss->filename;

    my $work_dir = $self->param_required('work_dir').'/'.$dirname;
    make_path($work_dir) unless -d $work_dir;

    my $output_dir = $self->param_required('export_dir').'/bed/ensembl-compara/'.$dirname;
    # remove_tree($output_dir);
    make_path($output_dir) unless -d $output_dir;

    $self->dataflow_output_id( {'dirname' => $dirname} );
}

1;
