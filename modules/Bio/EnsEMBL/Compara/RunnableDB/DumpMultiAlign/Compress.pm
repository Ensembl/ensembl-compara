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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::Compress.pm

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module runs gzip -9

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Compress;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

}

sub run {
    my $self = shift;

    #
    #Run gzip -9 command (with force option)
    #
    my $output_file = $self->param('output_dir') . "/" . $self->param('output_file');

    #Check existence of output_file (could be a glob for supercontig)
    my @out_files = glob $output_file;
    return unless @out_files;

    foreach my $out_file (@out_files) {
        return unless (-e $out_file);
    }

    #return unless (-e $output_file);
    my $cmd = "gzip -f -9 " . $output_file;
    if(my $return_value = system($cmd)) {
        $return_value >>= 8;
        die "system( $cmd ) failed: $return_value";
    }

    #
    #If maf_output_dir defined, move maf file from emf directory to maf
    #directory
    #
    if ($self->param('maf_output_dir')) {
	my $mv_cmd = "mv " . $self->param('output_dir') . "/" . $self->param('output_file') . ".gz " . $self->param('maf_output_dir');
	if(my $return_value = system($mv_cmd)) {
	    $return_value >>= 8;
	    die "system( $cmd ) failed: $return_value";
	}
    }

}

sub write_output {
    my $self = shift @_;

}

1;
