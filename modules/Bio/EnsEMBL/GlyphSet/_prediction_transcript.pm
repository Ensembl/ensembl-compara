package Bio::EnsEMBL::GlyphSet::_prediction_transcript;

use strict;

use Bio::EnsEMBL::Gene;

use base qw(Bio::EnsEMBL::GlyphSet::_transcript);

sub _das_type { return 'prediction_transcript'; }

sub _make_gene {
  my ($self, $transcript) = @_;
  my $gene = Bio::EnsEMBL::Gene->new;
  
  $gene->add_Transcript($transcript);
  $gene->stable_id($transcript->stable_id); # fake a stable id so that the data structures returned by features are correct.
  
  return $gene;
}

sub features {
  my $self     = shift;
  my $slice    = $self->{'container'};
  my $db_alias = $self->my_config('db');

  return $self->SUPER::features(map $self->_make_gene($_), map @{$slice->get_all_PredictionTranscripts($_, $db_alias) || []}, @{$self->my_config('logic_names')});
}

## Hacked url for prediction transcripts pt=xxx
sub href {
  my ($self, $gene, $transcript) = @_;
  
  return $self->_url({
    type   => 'Transcript',
    action => 'Summary',
    pt     => $transcript->stable_id,
    g      => undef,
    db     => $self->my_config('db')
  });
}

sub export_feature {
  my $self = shift;
  my ($feature, $transcript_id, $source) = @_;
  
  return $self->_render_text($feature, "$source prediction", { headers => [ 'transcript_id' ], values => [ $transcript_id ] });
}

1;
