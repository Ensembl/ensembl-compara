
=pod 

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::Emf2Maf

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

The RunnableDB module runs emf2maf jobs. It creates compression jobs

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Emf2Maf;

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

    #
    #Check if dummy jobs
    #
    if ($self->param('output_file') eq "") {
	return 1;
    }

    #
    #Rum emf2maf
    #
    my $cmd = $self->param('emf2maf_program') . " " . $self->param('output_file');
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

    #
    #Check if dummy jobs
    #
    if ($self->param('output_file') eq "") {
	return 1;
    }

    #
    #Create Compress jobs
    #
    my $maf_file = $self->param('output_file');
    $maf_file =~ s/\.emf$/.maf/;

    my $output_ids = "{\"output_file\"=>\"" . $maf_file . "\"";
    if ($self->param('maf_output_dir')) {
	$output_ids .= ",\"maf_output_dir\" => \"" . $self->param('maf_output_dir') . "\"";
    }
    $output_ids .= "}";

    $self->dataflow_output_id($output_ids, 2);


    #md5sum
    #my $md5sum_output_ids = "{\"output_dir\"=>\"" . $self->param('maf_output_dir') . "\"}";
    #$self->dataflow_output_id($md5sum_output_ids, 3);

}

#
#Check the number of genomic_align_blocks written is correct
#
sub _healthcheck {
    my ($self) = @_;

    $DB::single = 1;
    my $output_file = $self->param('output_file');
    $output_file =~ s/\.emf$/.maf/;
    my $cmd = "grep -c ^a " . $output_file;

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
	$sth->execute($output_file, $self->param('num_blocks'), $num_blocks);
	$sth->finish();
    }
}


1;
