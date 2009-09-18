package Bio::EnsEMBL::GlyphSet::fg_background_regulation;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);
#needed to shade the region covered by a regulatory feature in regulation detailed view.


sub _init {
  my ($self) = @_;  
  my $Config = $self->{'config'};
  my $slice = $self->{'container'}; 
  my $target_feature_id = $self->{'config'}->core_objects->regulation->stable_id;  
  my $strand = $self->strand;
  my $colour = 'wheat';
  my $x = 10;
  my $width = 40;
  my $pix_per_bp = $Config->transform->{'scalex'};




  my $fg_db = undef; ;
  my $db_type  = $self->my_config('db_type')||'funcgen';
  unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    if(!$fg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }
  
  my $reg_feat_adaptor = $fg_db->get_RegulatoryFeatureAdaptor;
  my $features = $reg_feat_adaptor->fetch_all_by_Slice($slice);
  foreach my $f (@$features){
    next unless $f->stable_id eq  $target_feature_id;
    $x = $f->start;
    $width = $f->end - $f->start ;
  }
   
  my $glyph = $self->Rect({
    x => $x,
    y => 0,
    width => $width,
    height => 0,
  });


  $self->join_tag($glyph, 'regfeat', $strand<0?0:1, 0, $colour, 'fill', -99);
  $self->join_tag($glyph, 'regfeat', $strand<0?1:0, 0, $colour, 'fill', -99); 
  $self->push($glyph);

return;
}
1;
