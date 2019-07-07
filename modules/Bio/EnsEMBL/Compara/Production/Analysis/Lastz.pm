=head1 LICENSE

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 AUTHORS

Abel Ureta-Vidal <abel@ebi.ac.uk>

=head1 NAME

Bio::EnsEMBL::Compara::Production::Analysis::Lastz - 

=head1 SYNOPSIS

  # To run a lastz job from scratch do the following.

  my $query = new Bio::SeqIO(-file   => 'somefile.fa',
                           -format => 'fasta')->next_seq;

  my $database = 'multifastafile.fa';

  my $lastz =  Bio::EnsEMBL::Compara::Production::Analysis::Lastz->new 
    ('-query'     => $query,
     '-database'  => $database,
     '-options'   => 'T=2');

  @featurepairs = @{$lastz->run()};

  foreach my $fp (@featurepairs) {
      print $fp->gffstring . "\n";
  }

  # Additionally if you have lastz runs lying around that need parsing
  # you can use the EnsEMBL blastz parser module 
  # perldoc Bio::EnsEMBL::Compara::Production::Analysis::Parser::Blastz


=head1 DESCRIPTION

Lastz takes a Bio::Seq (or Bio::PrimarySeq) object and runs lastz with against 
the specified multi-FASTA file database. Tthe output is parsed by 
Bio::EnsEMBL::Compara::Production::Analysis::Parser::Lastz and stored as Bio::EnsEMBL::DnaDnaAlignFeature 

Other options can be passed to the lastz program using the -options method

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::Production::Analysis::Lastz;


use warnings ;
use strict;

use File::Spec::Functions qw(catfile);
use File::Temp;

use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Compara::Production::Analysis::Blastz;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception;


sub run_lastz {
  my ($self, $query, $database) = @_;

  my $cmd = $self->param('pair_aligner_exe')." ".
            $query ." ".
            $database ." ".
            $self->param('method_link_species_set')->get_value_for_tag('param');

  my $BlastzParser;
  my $blastz_output_pipe = undef;
  if($self->debug > 1) {
    my $resultsfile = $self->worker_temp_directory.'/lastz.results';

    $cmd .=  " > ". $resultsfile;
    info("Running lastz...\n$cmd\n");

    throw("Error runing lastz cmd\n$cmd\n." .
                 " Returned error $? LASTZ EXIT: '" .
                 ($? >> 8) . "'," ." SIGNAL '" . ($? & 127) .
                 "', There was " . ($? & 128 ? 'a' : 'no') .
                 " core dump") unless(system($cmd) == 0);

    $BlastzParser = Bio::EnsEMBL::Compara::Production::Analysis::Blastz->
        new('-file' => $resultsfile);
  } else {
    info("Running lastz to pipe...\n$cmd\n");

    my $stderr_file = $self->worker_temp_directory()."/lastz_$$.stderr";

    open($blastz_output_pipe, "$cmd 2>$stderr_file |") ||
      throw("Error opening lasts cmd <$cmd>." .
                   " Returned error $? LAST EXIT: '" .
                   ($? >> 8) . "'," ." SIGNAL '" . ($? & 127) .
                   "', There was " . ($? & 128 ? 'a' : 'no') .
                   " core dump");

    $BlastzParser = Bio::EnsEMBL::Compara::Production::Analysis::Blastz->new('-fh' => $blastz_output_pipe);
    unless ($BlastzParser) {
        my $msg = $self->_slurp($stderr_file);
        $msg .= "\nUnable to parse blastz_output_pipe";
        throw($msg);
    }
  }

  my @results;

  while (defined (my $alignment = $BlastzParser->nextAlignment)) { # nextHSP-like
    push @results, $alignment;
  }
  close($blastz_output_pipe) if(defined($blastz_output_pipe));

  $self->cleanup_worker_temp_directory;

  return \@results;
}

1;
