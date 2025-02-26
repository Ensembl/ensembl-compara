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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::SymlinkPreviousDumps

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::SymlinkPreviousDumps;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my $self = shift;

	my $ftp_root = $self->param_required('ftp_root');
	my $dump_dir = $self->param_required('dump_dir');
    my $prev_rel_ftp_root = $self->param_required('prev_rel_ftp_root');

    my (@cmds, %missing_dump_mlsses);

	# first, symlink * from the mlss-specific dirs
	my $mlss_dump_dirs = $self->param_required('mlss_dump_dirs');
	foreach my $mlss_dir ( keys %$mlss_dump_dirs ) {
		my $prev_ftp_dump = "$prev_rel_ftp_root/$mlss_dir";
		# check dir is non-empty
		my @dir_files = glob "$prev_ftp_dump/*";
		if ( defined $dir_files[0] ) {
			my $curr_dump_dest = "$dump_dir/$mlss_dir";
			foreach my $dir_file ( @dir_files ) {
				push ( @cmds, "ln -sL $dir_file $curr_dump_dest/" );
			}
		} else {
			$missing_dump_mlsses{$mlss_dump_dirs->{$mlss_dir}} = 1;
		}
	}

	# next, symlink the individual archived files
	my $archived_dumps = $self->param_required('archived_dumps');
	foreach my $archive_prefix ( keys %$archived_dumps ) {
		my $prev_ftp_arch_pref = "$prev_rel_ftp_root/$archive_prefix.*";
		# check archive exists
		my @arch_file_glob = glob "$prev_ftp_arch_pref";
		my $prev_ftp_arch = $arch_file_glob[0] || undef;
		if ( $prev_ftp_arch ) {
			my $curr_arch_dest = "$dump_dir/$archive_prefix";
			my @dest_parts = split('/', $curr_arch_dest); 
			pop @dest_parts; # remove the last part
			$curr_arch_dest = join( '/', @dest_parts );

			push ( @cmds, "ln -sL $prev_ftp_arch $curr_arch_dest/" );
		} else {
			$missing_dump_mlsses{$archived_dumps->{$archive_prefix}} = 1;
		}
		
	}

	$self->param( 'symlink_cmds', \@cmds );

	my @missing_mlsses = keys %missing_dump_mlsses;
	$self->param( 'missing_mlsses', \@missing_mlsses ) if $missing_mlsses[0];
}

sub run {
	my $self = shift;

    $self->warning("RunnableDB::FTPDumps::SymlinkPreviousDumps is deprecated");

	my @symlink_cmds = @{ $self->param('symlink_cmds') };
	foreach my $this_cmd ( @symlink_cmds ) {
		print STDERR "$this_cmd\n";
		$self->run_command($this_cmd);
	}
}

sub write_output {
	my $self = shift;
	$self->dataflow_output_id( { mlss_ids => $self->param('missing_mlsses'), reuse_prev_rel => 0 }, 2 ) if $self->param('missing_mlsses');
}

1;
