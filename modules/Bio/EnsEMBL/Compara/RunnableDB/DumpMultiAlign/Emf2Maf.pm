=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
