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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateDumpJobs

=head1 SYNOPSIS

	Detect all new method_link_species_sets and generate dump jobs for each. Also, create a bash script
	to copy all old data from the previous release.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CreateCopyJobs;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        
        'cp_bash_outfile' => '#dump_dir#/cp_from_prev_rel.sh',
    };
}

sub fetch_input {
	my $self = shift;

        $self->load_registry($self->param('reg_conf')) if $self->param('reg_conf');
	my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param('compara_db') );

	my @copy_jobs;
	my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
	foreach my $mlss_id ( @{ $self->param_required('mlss_ids') } ) {
		my $mlss = $mlss_adaptor->fetch_by_dbID( $mlss_id );
		push( @copy_jobs, @{ $self->_copy_mlss($mlss) } );
	}

	# print Dumper \@copy_jobs;

	$self->param('copy_jobs', \@copy_jobs);
}

sub write_output {
	my $self = shift;

	my $cp_bash_outfile = $self->param('cp_bash_outfile');
	$self->warning("Writing bash script to $cp_bash_outfile");
	# open( my $out_fh, '>', $cp_bash_outfile );
	# print $out_fh join( "\n", @{ $self->param('copy_jobs') } );
	# close $out_fh;
}

sub _copy_mlss {
	my ( $self, $mlss ) = @_;

	my $curr_release = $self->param_required('curr_release');
	my $curr_ftp = $self->param_required('ftp_root') . "/release-$curr_release" ;
	my $prev_release = $curr_release - 1;
	my $prev_ftp = $self->param_required('ftp_root') . "/release-$prev_release" ;

	my @copy_jobs;
	my $mlss_filename = $mlss->filename;

	my $ftp_locations = $self->param('ftp_locations')->{$mlss->method->type};
	foreach my $loc ( @$ftp_locations ) {
		my $prev_loc = "$prev_ftp/$loc/$mlss_filename";
		my $curr_loc = "$curr_ftp/$loc/";
		
		print "-d $prev_loc ? ";
		if ( -d $prev_loc ) {
			print "Y\n";
			$prev_loc .= "/*";
			$curr_loc .= "$mlss_filename/";
		} else {
			print "N\n";
			$prev_loc .= ".*";
		}

		my $cp_cmd = "cp -L $prev_loc $curr_loc;";
		push( @copy_jobs, $cp_cmd );
	}

	print "-------------- " . $mlss->dbID . " --------------\n";
	print Dumper \@copy_jobs;
	print "\n";

	return \@copy_jobs;
}

1;
