=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::sequence;

### Displays DNA sequence track as a series of pastel-coloured blocks
### (labelled with appropriate letters at high zoom levels)

use strict;

use Bio::EnsEMBL::Feature;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub label_overlay { return 1; }
sub fixed         { return 1; }
sub errorTrack    {}

sub features {
  my ($self) = @_;
  my $start  = 0;
  my $seq    = uc $self->{'container'}->seq;
  my $strand = $self->strand;
  
  $seq =~ tr/ACGT/TGCA/ if $strand == -1;
  
  my @features = map {
    Bio::EnsEMBL::Feature->new(
      -start   => ++$start,
      -end     => $start,
      -strand  => $strand,
      -seqname => $_,
      -slice   => $self->{'container'},
    )
  } split //, $seq;
  
  return \@features;
}

# What to use as the colour key
sub colour_key {
  my ($self, $f) = @_;
  return lc $f->seqname;
}

# What to place on the feature
sub feature_label {
  my ($self, $f) = @_;
  return $f->seqname;
}

sub title {
  my ($self, $f) = @_;
  return sprintf '%s; Position: %s:%s', $f->seqname, $self->{'container'}->seq_region_name, $f->seq_region_start;
}

1;
