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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::Emf2Maf

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

The RunnableDB module runs emf2maf on a emf file

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Emf2Maf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },
        'cmd'   => '#emf2maf_program# #output_file#',   # Cannot use the array form becasue #output_file# may contain wildcard characters
    }
}

sub write_output {
    my $self = shift;

    $self->SUPER::write_output();

    #
    #Check number of genomic_align_blocks written is correct
    # 
    $self->_healthcheck();

}

#
#Check the number of genomic_align_blocks written is correct
#
sub _healthcheck {
    my ($self) = @_;

    my $output_file = $self->param('output_file');
    $output_file =~ s/\.emf$/.maf/;
    my $cmd = "grep ^a $output_file | wc -l";

    my $num_blocks = `$cmd`;
    chomp $num_blocks;
    if ($num_blocks != $self->param_required('num_blocks')) {
	die("Number of block dumped is $num_blocks but should be " . $self->param('num_blocks'));
    } else {
	print "Wrote " . $self->param('num_blocks') . " blocks\n";
	#Store results in table. Not really necessary but good to have 
	#visual confirmation all is well
	my $sql = "INSERT INTO healthcheck (filename, expected,dumped) VALUES (?,?,?)";
	my $sth = $self->dbc->prepare($sql);
	$sth->execute($output_file, $self->param('num_blocks'), $num_blocks);
	$sth->finish();
    }
}


1;
