package Bio::EnsEMBL::GlyphSet::_prediction_transcript;

use strict;

use Bio::EnsEMBL::Gene;

use base qw(Bio::EnsEMBL::GlyphSet::_transcript);

sub _das_type {
  return "prediction_transcript";
}

sub _make_gene {
  my( $self, $transcript ) = @_;
  my $gene = new Bio::EnsEMBL::Gene();
  $gene->add_Transcript( $transcript );
  return $gene;
}

sub features {
  my $self = shift;
  my $slice = $self->{'container'};
  my $db_alias = $self->my_config('db');
  my $analyses = $self->my_config('logicnames');

  my @genes = map { $self->_make_gene($_) }
              map { @{$slice->get_all_PredictionTranscripts( $_, $db_alias )||[]} }
              @$analyses;
  return \@genes;
}

## Hacked url for prediction transcripts pt=xxx
sub href {
  my ($self, $gene, $transcript) = @_;
  my $db_alias = $self->my_config('db');
  return $self->_url({'type'=>'Transcript','action'=>'Summary','pt'=>$transcript->stable_id,'g'=>undef,'db'=>$db_alias});
}

sub export_feature {
  my $self = shift;
  my ($feature, $transcript_id, $source) = @_;
  
  return $self->_render_text($feature, "$source prediction", { 'headers' => [ 'transcript_id' ], 'values' => [ $transcript_id ] });
}

1;
