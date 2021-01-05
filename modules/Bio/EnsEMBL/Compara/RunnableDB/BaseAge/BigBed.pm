=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

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
  my $file_list = join " ", (map {$bed_files->{$_}} sort {$a cmp $b} keys %$bed_files);
  my $cat_cmd = "cat $file_list > $concat_bed_file";
  $self->run_command($cat_cmd, { die_on_failure => 1 });

  $self->param('concat_file', $concat_bed_file);
}

sub write_output {
  my( $self) = @_;
  my $concat_file = $self->param('concat_file');
  #First check concat_file is not empty
  if (-s $concat_file) {
      my $cmd = [$self->param('program'), '-as='.$self->param('baseage_autosql'), '-type=bed3+3', $concat_file, $self->param('chr_sizes'), $self->param('big_bed_file')];
      $self->run_command($cmd, { die_on_failure => 1 });
  }
  else {
      die "$concat_file empty so cannot produce Big Bed file";
  }
}

1;

