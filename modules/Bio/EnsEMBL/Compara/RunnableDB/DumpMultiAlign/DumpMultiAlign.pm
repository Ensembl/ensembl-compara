
=pod 

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::DumpMultiAlign

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module runs DumpMultiAlign jobs. It creates emf2maf jobs if
necessary and compression jobs

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::DumpMultiAlign;

use strict;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisDataAdaptor;
use base ('Bio::EnsEMBL::Hive::ProcessWithParams');

=head2 strict_hash_format

    Description : Implements strict_hash_format() interface method of Bio::EnsEMBL::Hive::ProcessWithParams that is used to set the strictness level of the parameters' parser.
                  Here we return 0 in order to indicate that neither input_id() nor parameters() is required to contain a hash.

=cut

sub strict_hash_format {
    return 0;
}

sub fetch_input {
    my $self = shift;
}

sub run {
    my $self = shift;

    my $cmd = $self->param('cmd');

    #Write a temporary file to store gabs to dump
    if ($self->param('start') && $self->param('end')) {
	$self->_write_gab_file();
	$cmd .= " --file_of_genomic_align_block_ids " . $self->param('tmp_file');
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
	my $output_ids = "{\"emf2maf_program\" => \"" .$self->param('emf2maf_program') . "\", \"output_file\"=>\"" . $self->param('output_file') . "\", \"maf_output_dir\" => \"" . $self->param('maf_output_dir') . "\", \"num_blocks\" => \"" . $self->param('num_blocks') . "\"}";

	$self->dataflow_output_id($output_ids, 2);

    } else {
	#Send dummy jobs to emf2maf
	$self->dataflow_output_id("{}", 2);
    }

    #
    #Create Compress jobs
    #
    my $output_ids = "{\"output_file\"=>\"" . $self->param('output_file') . "\"}";
    $self->dataflow_output_id($output_ids, 1);
}

#
#Check the number of genomic_align_blocks written is correct
#
sub _healthcheck {
    my ($self) = @_;

    my $cmd;
    if ($self->param('format') eq "emf") {
	$cmd = "grep -c DATA " . $self->param('output_file');
    } elsif ($self->param('format') eq "maf") {
	$cmd = "grep -c ^a " . $self->param('output_file');
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
	my $sth = $self->analysis->adaptor->dbc->prepare($sql);
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

    my $sql = "SELECT * FROM other_gab WHERE genomic_align_block_id BETWEEN ? AND ?";
    my $sth = $self->analysis->adaptor->dbc->prepare($sql);
    $sth->execute($self->param('start'), $self->param('end'));
    
    my $tmp_file = "/tmp/other_gab_$$.out";
    $self->param('tmp_file', $tmp_file);
    
    open(FILE, ">$tmp_file") || die ("Couldn't open $tmp_file for writing"); 

    while (my $row = $sth->fetchrow_arrayref) {
	print FILE $row->[0] . "\n";

    }
    close(FILE);
    $sth->finish;
}

1;
