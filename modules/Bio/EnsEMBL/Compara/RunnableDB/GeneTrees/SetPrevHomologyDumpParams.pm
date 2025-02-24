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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SetPrevHomologyDumpParams

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SetPrevHomologyDumpParams;

use strict;
use warnings;

use File::Spec::Functions qw(catdir);
use List::Util qw(max);

use Bio::EnsEMBL::Hive::Utils qw(stringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $homology_dumps_shared_basedir = $self->param_required('homology_dumps_shared_basedir');
    my $prev_release = $self->param_required('prev_release');
    my $collection = $self->param_required('collection');

    my $prev_homology_collection_dir = catdir($homology_dumps_shared_basedir, $collection);

    my $prev_homology_dump_dir_path;
    my $previous_wga_file;

    if ( -d $prev_homology_collection_dir ) {

        opendir(my $dh, $prev_homology_collection_dir) or $self->throw("Could not open directory [$prev_homology_collection_dir]");
        my @release_dir_names = grep {
            $_ =~ /^[0-9]+$/
            && $_ <= $prev_release
            && -d catdir($prev_homology_collection_dir, $_)
        } readdir($dh);
        closedir $dh;

        if (scalar(@release_dir_names) > 0) {
            my $prev_homology_dump_dir_name = max(@release_dir_names);
            $prev_homology_dump_dir_path = catdir($prev_homology_collection_dir, $prev_homology_dump_dir_name);
            $previous_wga_file = '#prev_wga_dumps_dir#/#hashed_mlss_id#/#orth_mlss_id#.#member_type#.wga.tsv';
        }
    }

    $self->param('prev_homology_dumps_dir', $prev_homology_dump_dir_path);
    $self->param('prev_wga_dumps_dir', $prev_homology_dump_dir_path);
    $self->param('previous_wga_file', $previous_wga_file);
}


sub write_output {
    my ($self) = @_;

    foreach my $param_name ('prev_homology_dumps_dir', 'prev_wga_dumps_dir', 'previous_wga_file') {
        $self->add_or_update_pipeline_wide_parameter($param_name, stringify($self->param($param_name)));
    }
}


1;
