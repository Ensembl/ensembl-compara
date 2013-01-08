=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::Emf2Maf

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

The RunnableDB module runs emf2maf jobs. It creates compression jobs

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Emf2Maf;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

}

sub run {
    my $self = shift;

    #
    #Check if dummy jobs
    #
    if (!$self->param('output_file')) {
	return 1;
    }

    #
    #Rum emf2maf
    #
    my $full_path = $self->param('output_dir') . "/" . $self->param('output_file');
    my $cmd = $self->param('emf2maf_program') . " " . $full_path;
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
    if (!$self->param('output_file')) {
	return 1;
    }

    #Create emf Compress job
    my $emf_file = $self->param('output_file');
    my $emf_output_ids = {"output_file"=>$emf_file};
    $self->dataflow_output_id($emf_output_ids, 2);

    #
    #Create maf Compress jobs
    #
    my $maf_file = $self->param('output_file');
    $maf_file =~ s/\.emf$/.maf/;

    my $output_ids = "{\"output_file\"=>\"" . $maf_file . "\"";
    if ($self->param('maf_output_dir')) {
	$output_ids .= ",\"maf_output_dir\" => \"" . $self->param('maf_output_dir') . "\"";
    }
    $output_ids .= "}";

    $self->dataflow_output_id($output_ids, 2);


}

#
#Check the number of genomic_align_blocks written is correct
#
sub _healthcheck {
    my ($self) = @_;

    my $output_file = $self->param('output_dir') . "/" . $self->param('output_file');
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
	my $sth = $self->compara_dba->dbc->prepare($sql);
	$sth->execute($output_file, $self->param('num_blocks'), $num_blocks);
	$sth->finish();
    }
}


1;
