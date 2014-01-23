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

Bio::EnsEMBL::Compara::RunnableDB::BaseAge::BaseAge

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION


=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BaseAge::BigBed;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Variation::DBSQL::DBAdaptor;

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #concatenate all the sorted bed_files together 
  my $concat_bed_file = $self->worker_temp_directory . "/concat_ages.bed";

  my $bed_files = $self->param('bed_files');
  #sort alphabetically https://genome.ucsc.edu/goldenPath/help/bigBed.html 
  #Your BED file must be sorted by chrom then chromStart. You can use the UNIX sort command to do this: sort -k1,1 -k2,2n unsorted.bed > input.bed

  my @ordered_files;
  foreach my $seq_region (sort {$a cmp $b} keys %$bed_files) {
      my $sorted_bed_file = sort_bed($bed_files->{$seq_region});
      push @ordered_files, $sorted_bed_file;
  }
  my $file_list = join " ", @ordered_files;
  unless (system("cat $file_list > $concat_bed_file") == 0) {
      throw("Failed cat $file_list: $?\n");
  }

  $self->param('concat_file', $concat_bed_file);
  #Should be able to delete the original files now
  unlink @ordered_files;

  return 1;
}

sub run {
  my( $self) = @_;

  return 1;
}

sub write_output {
  my( $self) = @_;
  my $concat_file = $self->param('concat_file');
  #First check concat_file is not empty
  if (-s $concat_file) {
      my $cmd = join " ", $self->param('program'), $concat_file, $self->param('chr_sizes'), $self->param('big_bed_file');
      unless (system($cmd) == 0) {
          throw("Failed $cmd: $?\n");
      }
  } else {
      #empty concat_file
      unlink $concat_file;
  }

  return 1;

}

sub sort_bed {
    my ($bed_file) = @_;
    my $sorted_bed_file = $bed_file . ".sort";
    my $sort_cmd = "sort -k2,2n $bed_file > $sorted_bed_file";
    unless (system($sort_cmd) == 0) {
        throw("Problem running $sort_cmd: $!");
    }
    #remove original bed file
    unlink $bed_file;
    return $sorted_bed_file;
}


1;


