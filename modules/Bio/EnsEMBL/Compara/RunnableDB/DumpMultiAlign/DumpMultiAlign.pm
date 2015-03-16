=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

This RunnableDB module runs DumpMultiAlign jobs. It creates emf2maf jobs if
necessary and compression jobs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::DumpMultiAlign;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;
}

sub run {
    my $self = shift;

    my $cmd = $self->param('cmd');

    #append full path to output_file
    my $full_output_file = $self->param('output_dir') . "/" . $self->param('output_file');
    $cmd .= " --output_file $full_output_file";

    #Write a temporary file to store gabs to dump
    if ($self->param('start') && $self->param('end')) {
        my $tmp_file = $self->_write_gab_file();
        $cmd .= " --file_of_genomic_align_block_ids " . $tmp_file;

        $self->param('tmp_file', $tmp_file);
    }

    #Convert compara_db into either a url or a name
    if ($self->param('compara_db') =~ /^mysql:\/\//) {
	$cmd .= " --compara_url " . $self->param('compara_db');
    } else {
	$cmd .= " --dbname " . $self->param('compara_db');
    }

    #Convert db_urls into a string
    if ($self->param('db_urls')) {
	my $str = join ",", @{$self->param('db_urls')};
	$cmd .= (" --db '" . $str . "'");
    }

    if ($self->param('reg_conf')) {
	$cmd .= " --reg_conf " . $self->param('reg_conf');
    }

    #print "cmd $cmd \n";

    #
    #Run DumpMultiAlign cmd
    #
    if(my $return_value = system($cmd)) {
        $return_value >>= 8;
        die "system( $cmd ) failed: $return_value";
    }
    #
    #Check number of genomic_align_blocks written is correct
    # 
    $self->_healthcheck();
}

sub write_output {
    my $self = shift @_;

    #delete tmp file
    unlink($self->param('tmp_file'));

    #
    #Create emf2maf job if necesary
    #
    if ($self->param('maf_output_dir')) {
	my $output_ids = {'output_file'=>$self->param('dumped_output_file'),
			  'num_blocks' =>$self->param('num_blocks')};

	$self->dataflow_output_id($output_ids, 2);

    } else {
	#Send dummy jobs to emf2maf
	#$self->dataflow_output_id("{}", 2);

	#Send to compress
	my $output_ids = {"output_file"=>$self->param('dumped_output_file')};
	$self->dataflow_output_id($output_ids, 1);
	
    }

    #
    #Create Compress jobs - could this be put in the else and then emf2maf calls compress with both emf and maf?
    #

    #my $output_ids = "{\"output_file\"=>\"" . $self->param('dumped_output_file') . "\"}";
    #$self->dataflow_output_id($output_ids, 1);
}

#
#Check the number of genomic_align_blocks written is correct
#
sub _healthcheck {
    my ($self) = @_;
    
    #Find out if split into several files
    my $dump_cmd = $self->param('extra_args');
    my $chunk_num = $dump_cmd =~ /chunk_num/;
    my $output_file = $self->param('output_dir') . "/" . $self->param('output_file');

    #not split by chunk eg supercontigs so need to check all supercontig* files
    if (!$chunk_num) {
	if ($output_file =~ /\.[^\.]+$/) {
	    $output_file =~ s/(\.[^\.]+)$/_*$1/;
	}
    } else {
	#Have chunk number in filename
	$output_file = $self->param('output_dir') . "/" . $self->param('dumped_output_file');
    }

    my $cmd;
    if ($self->param('format') eq "emf") {
	$cmd = "grep DATA " . $output_file . " | wc -l";

    } elsif ($self->param('format') eq "maf") {
	$cmd = "grep ^a " . $output_file . " | wc -l";
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

    my $tmp_file = $worker_temp_directory . "other_gab_$$.out";
    
    open(FILE, ">$tmp_file") || die ("Couldn't open $tmp_file for writing"); 
    while (my $row = $sth->fetchrow) {
	print FILE $row . "\n";
    }
    close(FILE);
    $sth->finish;

    return $tmp_file;
}

1;
