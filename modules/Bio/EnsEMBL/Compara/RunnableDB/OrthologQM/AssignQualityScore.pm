=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore

=head1 SYNOPSIS

	Writes final score for the homology into homology.wga_coverage

=head1 DESCRIPTION

	Inputs:
	{homology_id => score}

	Outputs:
	No data is dataflowed from this runnable
	Score is written to homology table of compara_db option

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore;

use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);
use Bio::EnsEMBL::Compara::Utils::DistributionTag qw(write_n_tag);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my $self = shift;

	my @orth_ids = @{ $self->param_required('orth_ids') };
	my %max_quality;

	my $sql = 'select MAX(wga_cov) from ( select alignment_mlss, AVG(quality_score) wga_cov from ortholog_quality where homology_id = ? group by alignment_mlss ) wga';
	my $sth = $self->data_dbc->prepare($sql);
	foreach my $oid ( @orth_ids ){
		$sth->execute($oid);
		$max_quality{$oid} = $sth->fetchrow_arrayref->[0] or $self->warning("Cannot find quality scores in db for homology id $oid");
        $max_quality{$oid} = 0 unless $max_quality{$oid}; # default to 0 like GOC
    }

	$self->param('max_quality', \%max_quality);
}

=head2 write_output

Description: write avg score to file

=cut

sub write_output {
    my $self = shift;

    # disconnect from dbs
    $self->compara_dba->dbc->disconnect_if_idle();
    $self->dbc->disconnect_if_idle() if $self->dbc;
    $self->data_dbc->disconnect_if_idle();

    my $member_type = $self->param_required('member_type');
    my $dba  = $self->get_cached_compara_dba('alignment_db');
    my $mlss_adaptor = $dba->get_MethodLinkSpeciesSetAdaptor();
    my @aln_mlss_ids  = @{ $self->param_required( 'aln_mlss_ids' ) };

    my $output_file = $self->param('output_file');
    my $reuse_file = $self->param('reuse_file');
    $self->run_command("mkdir -p " . dirname($output_file)) unless -d dirname($output_file);
    my $write_mode = '>';
    if ( -e $reuse_file ) {
        $self->run_command("cp $reuse_file $output_file");
        $write_mode = '>>';
    }

    my %max_quality = %{ $self->param('max_quality') };
    open( my $out_fh, $write_mode, $output_file ) or die "Cannot open $output_file for writing";

    # write header if we're starting from an empty file
    print $out_fh "homology_id\twga_coverage\n" if ( ! -e $reuse_file );

    print $out_fh join("\n", map(sprintf("%d\t%f", $_, $max_quality{$_}), keys %max_quality));
    close $out_fh;

    $self->warning("Scores written to $output_file!");

    foreach my $mlss_id ( @aln_mlss_ids ) {
        my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);
        print "Writing n_${member_type}_wga_score to the database\n" if $self->debug;
        $self->write_n_tag($mlss, "${member_type}_wga", \%max_quality);
        print "Tag: n_${member_type}_wga_score written!\n\n" if $self->debug;
    }
}

1;
