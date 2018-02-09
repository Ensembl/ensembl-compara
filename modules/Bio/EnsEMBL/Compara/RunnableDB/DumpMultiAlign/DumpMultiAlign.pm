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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::DumpMultiAlign

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module runs DumpMultiAlign jobs.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::DumpMultiAlign;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },
        'cmd' => [ 'perl', '#dump_program#', '--species', '#species#', '--mlss_id', '#dump_mlss_id#', '--masked_seq', '#masked_seq#', '--split_size', '#split_size#', '--output_format', '#format#', '--output_file', '#output_file_gen#' ],

        'dump_mlss_id'  => '#mlss_id#',     # By default we still dump "mlss_id"

        'extra_args'    => [],
    }
}


sub fetch_input {
    my $self = shift;

    my $cmd = $self->param('cmd');
    push @$cmd, @{$self->param_required('extra_args')};

    #Write a temporary file to store gabs to dump
    if ($self->param('start') && $self->param('end')) {
        my $tmp_file = $self->_write_gab_file();
        push @$cmd, '--file_of_genomic_align_block_ids', $tmp_file;

        $self->param('tmp_file', $tmp_file);
    }

    #Convert compara_db into either a url or a name
    if ($self->param('compara_db') =~ /^mysql:\/\//) {
	push @$cmd, '--compara_url', $self->param('compara_db');
    } else {
	push @$cmd, '--dbname', $self->param('compara_db');
    }

    if ($self->param('registry')) {
	push @$cmd, '--reg_conf', $self->param('registry');
    }
}

sub write_output {
    my $self = shift @_;

    $self->SUPER::write_output();

    #Check number of genomic_align_blocks written is correct
    $self->_healthcheck();

    #delete tmp file
    unlink($self->param('tmp_file')) if $self->param('tmp_file');
}

#
#Check the number of genomic_align_blocks written is correct
#
sub _healthcheck {
    my ($self) = @_;
    
    my $output_file = $self->param('output_file');

    my $cmd;
    if ($self->param('format') eq "emf") {
	$cmd = "grep DATA " . $output_file . " | wc -l";

    } elsif ($self->param('format') eq "maf") {
	$cmd = "grep ^a " . $output_file . " | wc -l";
    } else {
        die '_healthcheck() is not implemented for '.$self->param('format')."\n";
    }
    my $num_blocks = `$cmd`;
    chomp $num_blocks;
    if ($num_blocks != $self->param('num_blocks')) {
	die("Number of block dumped is $num_blocks but should be " . $self->param('num_blocks'));
    } else {
	print "Wrote " . $self->param('num_blocks') . " blocks\n";
	#Store results in table. Not really necessary but good to have 
	#visual confirmation all is well
	my $sql = "INSERT INTO healthcheck (filename, expected,dumped) VALUES (?,?,?)";
	my $sth = $self->db->dbc->prepare($sql);
	$sth->execute($self->param('output_file'), $self->param('num_blocks'), $num_blocks);
	$sth->finish();
    }
}

#
#Write temporary file containing a list of genomic_align_block_ids for 
#inputting into DumpMultiAlign
#
sub _write_gab_file {
    my ($self) = @_;

    my $sql = "SELECT genomic_align_block_id FROM other_gab WHERE genomic_align_block_id BETWEEN ? AND ?";
    my $sth = $self->db->dbc->prepare($sql);
    $sth->execute($self->param('start'), $self->param('end'));
    
    my $worker_temp_directory   = $self->worker_temp_directory;

    my $tmp_file = $worker_temp_directory . "/other_gab_$$.out";
    
    open my $tmp_fh, '>', $tmp_file || die ("Couldn't open $tmp_file for writing");
    while (my $row = $sth->fetchrow) {
	print $tmp_fh $row . "\n";
    }
    close($tmp_fh);
    $sth->finish;

    return $tmp_file;
}

1;
