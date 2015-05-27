=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

### MODULE AT RISK OF DELETION ##
# This module is unused in the core Ensembl code, and is at risk of
# deletion. If you have use for this module, please contact the
# Ensembl team.
### MODULE AT RISK OF DELETION ##

package EnsEMBL::Draw::GlyphSet::tsv_missing;

### Error track for Transcript/Population/Image

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);
use EnsEMBL::Web::Utils::Tombstone qw(tombstone);

sub new {
  my $self = shift;
  tombstone('2015-04-16','ds23');
  $self->SUPER::new(@_);
}

# The filter message refers to the number of SNPs removed from the 'snp_fake' track
# i.e. the number will not change if you filter on SARA SNPs

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);


  my $configure_text = "The 'Configure this page' link in the menu on the left hand side of this page can be used to customise the exon context and types of variations displayed above.";
  $self->errorTrack( $configure_text);

  my $counts = $self->{'config'}->{'snp_counts'};
  return unless ref $counts eq 'ARRAY';
  
  my $text;
  if ($counts->[0]==0 ) {
    $text .= "There are no SNPs within the context selected for this transcript.";
  } elsif ($counts->[1] ==0 ) {
    $text .= "The options set in the page configuration have filtered out all $counts->[0] variations in this region.";
  } elsif ($counts->[0] == $counts->[1] ) {
    $text .= "None of the variations are filtered out by the Source, Class and Type filters.";
  } else {
    $text .= ($counts->[0]-$counts->[1])." of the $counts->[0] variations in this region have been filtered out by the Source, Class and Type filters.";
  }
  $self->errorTrack( $text, 0, 14  );

  # Context filter
  return unless defined $counts->[2];

  my $context_text;
  if ($counts->[2]==0) {
    $context_text = "None of the intronic variations are removed by the Context filter.";
  }
  elsif ($counts->[2]==1) {
    $context_text = $counts->[2]." intronic variation has been removed by the Context filter.";
  }
 else {
    $context_text = $counts->[2]." intronic variations are removed by the Context filter.";
  }
  $self->errorTrack( $context_text, 0, 28 );

  return 1;
}

1;

