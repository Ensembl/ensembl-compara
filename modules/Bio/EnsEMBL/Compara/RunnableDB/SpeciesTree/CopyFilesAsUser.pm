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

Bio::EnsEMBL::Hive::RunnableDB::SpeciesTree::CopyFilesAsUser

=head1 SYNOPSIS

'become' a user before copying a list of files to a given location.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::CopyFilesAsUser;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Utils::RunCommand;

# use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;
	my $dest_dir = $self->param_required('destination_dir');
	my @filelist = @{ $self->param_required('file_list') };
	my $become_user = $self->param('become_user');

	my $cmd;

	$cmd .= "become - $become_user; "  if ( $become_user );
	foreach my $f ( @filelist ) {
		$cmd .= "cp $f $dest_dir; ";
	}
	print "cmd: $cmd\n\n";
	$self->param('cmd', $cmd);
}

sub run {
	my $self = shift;

	my $cmd = $self->param_required('cmd');
	my $options = {};
    $options->{debug} = $self->debug;

	Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd, $options);
}

1;