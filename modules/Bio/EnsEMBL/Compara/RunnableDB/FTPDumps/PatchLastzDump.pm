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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::PatchLastzDump

=head1 SYNOPSIS

	1. locate the newly copied patch dumps and the tarball from the old dumps
	2. untar/gz the old dump to tmp dir (because the new and old dir names will be the same - avoid clashes or uncertainty)
	3. copy everything to patch dump dir, md5sum, re-tar/gz

=head1 DEPRECATION NOTICE

This runnable is deprecated, and may be removed in a future release.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::PatchLastzDump;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my $self = shift;

	my $mlss_id = $self->param_required('mlss_id');
	my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
	my $mlss_filename = $mlss->filename;
	$self->param( 'mlss_filename', $mlss_filename );


	# construct paths and check files are in place
	my $lastz_dump_path = $self->param('lastz_dump_path');

	# where patches have been dumped
	my $dump_root = $self->param_required( 'dump_dir' );
	my $patch_dump_dir = "$dump_root/$lastz_dump_path/$mlss_filename";
	die "Cannot find patch dumps for mlss_id $mlss_id : $patch_dump_dir does not exist" unless -d $patch_dump_dir;
	my @patch_dumps = glob "$patch_dump_dir/*";
	die "No patch dumps for mlss_id $mlss_id in $patch_dump_dir" unless $patch_dumps[0];
	$self->param( 'patch_dump_dir', $patch_dump_dir );

	# where dump tarball of full lastz lives (from previous release)
    my $prev_rel_ftp_root = $self->param_required('prev_rel_ftp_root');
    my $prev_rel_tarball = "$prev_rel_ftp_root/$lastz_dump_path/$mlss_filename*";

	my @tarballs = glob "$prev_rel_tarball";
	die "Cannot find previous release tarball for mlss_id $mlss_id : $prev_rel_tarball\n" unless defined $tarballs[0];
	$prev_rel_tarball = $tarballs[0];
	$self->param( 'prev_rel_tarball', $prev_rel_tarball );
}

sub run {
	my $self = shift;

    $self->warning("RunnableDB::FTPDumps::PatchLastzDump is deprecated, and may be removed in a future release");

	my $prev_rel_tarball = $self->param('prev_rel_tarball');
	my $patch_dump_dir = $self->param('patch_dump_dir');
	my $mlss_filename = $self->param('mlss_filename');

	my $tmp_dir = $self->worker_temp_directory;
	print "TMP_DIR: $tmp_dir\n";

	# some archives are .tar.gz, some just .tar
	my $tar_opts = 'xf';
	$tar_opts .= 'z' if $prev_rel_tarball =~ /gz$/;

	# use -C and --strip-components to specify the name of the unzipped directory
	# this is only important in the transition period, where extracted dirs may still be
	# using the old standards, while the tar.gz may be using the new naming standard
	my @untar_cmd = (
		"cd $tmp_dir",
		"mkdir -p $mlss_filename",
		"tar $tar_opts $prev_rel_tarball -C $mlss_filename --strip-components 1"
	);
	my $untar_run = $self->run_command( join("; ", @untar_cmd) );
	die $untar_run->err if $untar_run->err;

    my @merge_cmd = (
    	"cd $patch_dump_dir",
    	"mv $tmp_dir/$mlss_filename/* .",
    	"rm MD5SUM",
    	"md5sum *.maf* > MD5SUM",
    );
    my $merge_run = $self->run_command( join('; ', @merge_cmd) );

    $patch_dump_dir =~ s/\/$//;
    my @tar_cmd = (
    	"cd $patch_dump_dir",
    	"cd ../",
	    "tar cfz $mlss_filename.tar.gz $mlss_filename/",
	    "rm -r $mlss_filename/",
    );
    my $tar_run = $self->run_command( join('; ', @tar_cmd) );
}

1;
