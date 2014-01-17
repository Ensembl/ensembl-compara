=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::GlyphSet::codonseq;

use strict;

use Bio::EnsEMBL::Feature;
use Bio::Seq;

use base qw(Bio::EnsEMBL::GlyphSet::sequence);

# We base this on the sequence drawing as the only
# code which is different is the code that gets
# the features

# We have to create fake features in the features call
sub features {
  my $self        = shift;
  my $seq         = $self->{'container'}->subseq(-2, $self->{'container'}->length + 4);
  my $strand      = $self->strand;
  my $codon_table = ($self->{'container'}->get_all_Attributes('codon_table')->[0] || {})->{'value'};
  my @features;
  
  foreach my $phase (0..2) {
    my $string = substr $seq, $phase, 3 * int((length($seq) - $phase)/3);
    
    if ($strand == -1) { # Reverse complement sequence
       $string = reverse $string;
       $string =~ tr/AGCTagct/TCGAtcga/;
    }
    
    my $bioseq = Bio::Seq->new(-seq => $string, -moltype => 'dna');
    
    $string = $bioseq->translate(undef, undef, undef, $codon_table)->seq;
    $string = reverse $string if $strand == -1;
    
    my $start = $phase - 5;
    
    push @features, map {
      Bio::EnsEMBL::Feature->new(
        -start   => $start += 3,
        -end     => $start +  2,
        -seqname => $_,
        -strand  => $strand,
        -slice   => $self->{'container'},
      )
    } split //, $string;
  }
  
  return \@features;
}

sub title {
  my ($self, $f) = @_;
  my $start = $self->{'container'}->start - 1;
  return sprintf '%s; Location: %s:%s-%s', $f->seqname, $self->{'container'}->seq_region_name, $f->seq_region_start, $f->seq_region_end;
}

1;
