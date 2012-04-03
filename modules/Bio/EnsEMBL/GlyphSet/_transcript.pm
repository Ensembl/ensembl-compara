package Bio::EnsEMBL::GlyphSet::_transcript;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_transcript);

sub features {
  my $self     = shift;
  my $slice    = $self->{'container'};
  my $db_alias = $self->my_config('db');
  my $analyses = $self->my_config('logic_names');
  my @features;
  
  ## FIXME - this is an ugly hack!
  if ($slice->isa('Bio::EnsEMBL::LRGSlice') && $analyses->[0] ne 'LRG_import') {
    @features = map @{$slice->feature_Slice->get_all_Genes($_, $db_alias) || []}, @$analyses;
  } else {
    @features = map @{$slice->get_all_Genes($_, $db_alias, 1) || []}, @$analyses;
  }
  
  return \@features;
}

sub export_feature {
  my ($self, $feature, $transcript_id, $transcript_name, $gene_id, $gene_name, $gene_type, $gene_source) = @_;
  
  return $self->_render_text($feature, 'Exon', {
    headers => [ 'gene_id', 'gene_name', 'transcript_id', 'transcript_name', 'exon_id', 'gene_type' ],
    values  => [ $gene_id, $gene_name, $transcript_id, $transcript_name, $feature->stable_id, $gene_type ]
  }, { source => $gene_source });
}

sub href {
  my ($self, $gene, $transcript) = @_;
  my $hub    = $self->{'config'}->hub;
  my $params = {
    %{$hub->multi_params}
    species    => $self->species,
    type       => $transcript ? 'Transcript' : 'Gene',
    action     => $self->my_config('zmenu') ? $self->my_config('zmenu') : $hub->action,
    g          => $gene->stable_id,
    db         => $self->my_config('db'),
    calling_sp => $hub->species,
    real_r     => $hub->param('r'),
  };

  $params->{'r'} = undef                  if $self->{'container'}{'web_species'} ne $self->species;
  $params->{'t'} = $transcript->stable_id if $transcript;

  return $self->_url($params);
}

1;
