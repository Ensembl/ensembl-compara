package Bio::EnsEMBL::GlyphSet::_lrg_transcript;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::_transcript);

sub features {
  my $self     = shift;
  my $slice    = $self->{'container'};
  my $db_alias = $self->my_config('db');
  my $analyses = $self->my_config('logic_names');
  
  return [ map { /LRG/i ? @{$slice->get_all_Genes($_, $db_alias) || []} || () }  @$analyses ];
}

sub export_feature {
  my ($self, $feature, $transcript_id, $transcript_name, $gene_id, $gene_name, $gene_type) = @_;
  
  return $self->_render_text($feature, 'Exon', {
    headers => [ 'gene_id', 'gene_name', 'transcript_id', 'transcript_name', 'exon_id', 'gene_type' ],
    values  => [ $gene_id, $gene_name, $transcript_id, $transcript_name, $feature->stable_id, $gene_type ]
  });
}

1;
