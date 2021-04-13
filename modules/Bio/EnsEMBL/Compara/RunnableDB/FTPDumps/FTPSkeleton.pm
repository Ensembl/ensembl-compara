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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::FTPSkeleton

=head1 SYNOPSIS

	Create a skeleton of the FTP directory structure given a set of mlss_ids. 

	Inputs:
	compara_db    location of compara db
	dump_dir      where to create these new directories
	mlss_ids      arrayref of mlss_ids for which to make these directories

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::FTPSkeleton;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        ftp_locations => {
        	LASTZ_NET => ['maf/ensembl-compara/pairwise_alignments'],
        	EPO => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
        	EPO_EXTENDED => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
        	PECAN => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
        	GERP_CONSTRAINED_ELEMENT => ['bed/ensembl-compara'],
            GERP_CONSERVATION_SCORE  => ['compara/conservation_scores'],
        },
    }
}

sub fetch_input {
	my $self = shift;

	# my ( @mlss_dump_dirs, @archived_dumps );
	my ( %mlss_dump_dirs, %archived_dumps );
	my %ftp_locations = %{ $self->param_required('ftp_locations') };	
	foreach my $method_type ( keys %ftp_locations ) {
		my @base_dirlist = @{ $ftp_locations{$method_type} };		
		my %mlss_dirlist = %{ $self->_mlss_dirs($method_type) };
		foreach my $bdir ( @base_dirlist ) {
			# since LASTZ dumps are archived, we don't need to make
			# per-MLSS dirs, just the base (pairwise_alignments) dir
			$mlss_dump_dirs{$bdir} = 'LASTZ_NET' if $method_type eq 'LASTZ_NET';
			foreach my $mdir ( keys %mlss_dirlist ) {
				if ( $method_type eq 'LASTZ_NET' ) {
					$archived_dumps{"$bdir/$mdir"} = $mlss_dirlist{$mdir};
				} else {
					# otherwise, create dirs for each MLSS
					$mlss_dump_dirs{"$bdir/$mdir"} = $mlss_dirlist{$mdir};
				}
				
			}
		}
	}
	$self->param('mlss_dump_dirs', \%mlss_dump_dirs);
	$self->param('archived_dumps', \%archived_dumps);
}

sub run {
	my $self = shift;

	my $dump_dir = $self->param_required('dump_dir');
	foreach my $mlss_dir ( keys %{ $self->param('mlss_dump_dirs') } ) {
		my $mkdir_cmd = "mkdir -p $dump_dir/$mlss_dir";
		print STDERR "Command to run: $mkdir_cmd\n" if $self->debug;
		$self->run_command($mkdir_cmd);
	}
}

sub write_output {
	my $self = shift;
	$self->dataflow_output_id( { 
		mlss_dump_dirs => $self->param('mlss_dump_dirs'),
		archived_dumps => $self->param('archived_dumps'),
	}, 1 );
}

sub _mlss_dirs {
	my ($self, $method_type) = @_;

	my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
	my @these_mlsses = map { $mlss_adaptor->fetch_by_dbID($_) } @{ $self->param_required('mlss_ids') };
	my %mlss_dirs;
	foreach my $mlss ( @these_mlsses ) {
		$mlss_dirs{ $mlss->filename } = $mlss->dbID if $mlss->method->type eq $method_type;
	}
	return \%mlss_dirs;
}

1;
