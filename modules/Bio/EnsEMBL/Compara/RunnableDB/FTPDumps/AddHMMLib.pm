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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::AddHMMLib

=head1 DESCRIPTION

Will add a symlink to the HMM library to the FTP. The library is a
compressed tar archive that will automatically be generated if missing or
invalid.

The reference tar archive is given in "ref_tar_path_templ" and the symlink
will be put under the dir/name given in "tar_ftp_path". If needed, the
archive will be generated from "hmm_library_basedir".

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::AddHMMLib;

use warnings;
use strict;

use File::Basename;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
    my $self = shift;

    # Get the name of the current library
    my $hmm_library_basedir = $self->param_required('hmm_library_basedir');
    chop $hmm_library_basedir if $hmm_library_basedir =~ /\/$/; # otherwise basename returns an empty string
    my $library_name = basename($hmm_library_basedir);

    my $ref_tar_path = sprintf($self->param_required('ref_tar_path_templ'), $library_name);

    # Check if the tar file seems valid
    my $is_tar_file_ok = 0;
    if (-s $ref_tar_path) {
        my $cmd = ['tar', 'tzf', $ref_tar_path];
        my $run_cmd = $self->run_command($cmd);
        unless ($run_cmd->exit_code) {
            # Sanity check: the library must have move than 500 files
            my $nlines = $run_cmd->out =~ tr/\n//;
            if ($nlines >= 500) {
                $is_tar_file_ok = 1;
            } else {
                $self->warning("$ref_tar_path only contains $nlines entries. This seems too small for an HMM library. Regenerating it now");
            }
        }
    }

    # Otherwise regenerate it
    unless ($is_tar_file_ok) {
        # Tar from the parent directory
        my $cmd = ['tar', 'czf', $ref_tar_path, '-C', dirname($hmm_library_basedir), $library_name];
        $self->run_command($cmd, { die_on_failure => 1, });
    }

    my $tar_ftp_path = $self->param_required('tar_ftp_path');
    # Create the directory
    my $cmd1 = ['mkdir', '-p', dirname($tar_ftp_path)];
    $self->run_command($cmd1, { die_on_failure => 1, });
    # And the symlink
    my $cmd2 = ['ln', '-sf', $ref_tar_path, $tar_ftp_path];
    $self->run_command($cmd2, { die_on_failure => 1, });
}

1;
