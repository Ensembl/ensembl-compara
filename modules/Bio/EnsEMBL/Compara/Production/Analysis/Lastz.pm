=head1 LICENSE

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
            $database ." ".
            $query ." ".
            $self->param('method_link_species_set')->get_value_for_tag('param');

  my @results;
  my $stderr_file = $self->worker_temp_directory()."/lastz_$$.stderr";

  $self->read_from_command("$cmd 2>$stderr_file", sub {

    my $blastz_output_pipe  = shift;
    my $BlastzParser        = Bio::EnsEMBL::Compara::Production::Analysis::Blastz->new('-fh' => $blastz_output_pipe);

    unless ($BlastzParser) {
        my $msg = $self->_slurp($stderr_file);
        $msg .= "\nUnable to parse blastz_output_pipe";
        throw($msg);
    }


  while (defined (my $alignment = $BlastzParser->nextAlignment)) { # nextHSP-like
    push @results, $alignment;
  }

  } );

  return \@results;
}

1;
