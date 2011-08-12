package Bio::EnsEMBL::GlyphSet::fg_regulatory_features;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return sprintf 'Reg. Features from cell line %s', $_[0]->my_config('cell_line'); }

sub class {
  return 'group';
}

sub features {
  my ($self) = @_;
  my $slice = $self->{'container'}; 
  my $Config = $self->{'config'};
  my $type = $self->check();
 
  my $fg_db = undef;
  my $db_type  = $self->my_config('db_type')||'funcgen';
  unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    if(!$fg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }
  
  my $reg_features = $self->fetch_features($fg_db, $slice, $Config);

  return $reg_features;
}

sub fetch_features {
  my ($self, $db, $slice, $Config ) = @_;
  my $cell_line = $self->my_config('cell_line');  


  my $fsa = $db->get_FeatureSetAdaptor(); 
  if (!$fsa) {
    warn ("Cannot get get adaptors: $fsa");
    return [];
  }

  my @reg_feature_sets = @{$fsa->fetch_all_displayable_by_type('regulatory')}; 
  foreach my $set (@reg_feature_sets) {  
    next unless $set->cell_type->name =~/$cell_line/;
    my @rf_ref = @{$set->get_Features_by_Slice($slice)}; 
    if(@rf_ref && !$self->{'config'}->{'fg_regulatory_features_legend_features'} ) {
     #warn "...................".ref($self)."........................";
      $self->{'config'}->{'fg_regulatory_features_legend_features'}->{'fg_reglatory_features'} = { 'priority' => 1020, 'legend' => [] };
    }
    $self->{'config'}->{'reg_feats'} = \@rf_ref;
  }
    
  my $reg_feats = $self->{'config'}->{'reg_feats'} || [];   
  if (@$reg_feats && $self->{'config'}->{'fg_regulatory_features_legend_features'} ){
    $self->{'config'}->{'fg_regulatory_features_legend_features'}->{'fg_regulatory_features'} = {'priority' =>1020, 'legend' => [] };	
  }
  
  return $reg_feats;
}

sub colour_key {
  my ($self, $f) = @_;
  my $type = $f->feature_type->name();
  
  if ($type =~/Promoter/){$type = 'Promoter_associated';}
  elsif ($type =~/Non/){$type = 'Non-genic';}
  elsif ($type =~/Gene/){$type = 'Genic';}
  elsif ($type =~/Pol/){warn $type; $type = 'poliii_associated'}
  else  {$type = 'Unclassified';}
  return lc($type);
}


sub tag {
  my ($self, $f) = @_;
  my $type =$f->feature_type->name();
  if    ($type =~/Promoter/){$type = 'Promoter_associated';}
  elsif ($type =~/Non/){$type = 'Non-genic';}
  elsif ($type =~/Gene/){$type = 'Genic';}
  elsif ($type =~/Pol/){$type = 'poliii_associated'}
  else {$type = 'Unclassified';}

  $type = lc($type);
  my $colour = $self->my_colour( $type );

  my @loci = @{$f->get_underlying_structure};
  my $bound_end = pop @loci;
  my $end               = pop @loci;
  my ($bound_start, $start, @mf_loci) = @loci;

  my @result = ();
  # Draw bound start/ends
  push @result, { 
  'style' => 'fg_ends',
  'colour' => $colour,
  'start' => $f->bound_start,
  'end' => $f->bound_end
  };
  # Draw motif features
  while ( my ($mf_start, $mf_end) = splice (@mf_loci, 0, 2) ){ 
    push @result, {
      'style'  => 'rect',
      'colour' => 'black',
      'start'  => $mf_start,
      'end'    => $mf_end,
      'class'  => 'group'
    };
  }

  return @result;

}

sub highlight {
  my ($self, $f, $composite,$pix_per_bp, $h) = @_;
  my $id = $f->stable_id;
  ## Get highlights...
  my %highlights;
  @highlights{$self->highlights()} = (1);

  return unless $highlights{$id};
  $self->unshift( $self->Rect({  # First a black box!
    'x'         => $composite->x() - 2/$pix_per_bp,
    'y'         => $composite->y() -2, ## + makes it go down
    'width'     => $composite->width() + 4/$pix_per_bp,
    'height'    => $h + 4,
    'colour'    => 'highlight2',
    'absolutey' => 1,
  }));
}

sub href {
  my ($self, $f) = @_;
  my $cell_line = $self->my_config('cell_line');
  my $id = $f->stable_id;
  my $href = $self->_url
  ({
    'species' =>  $self->species, 
    'type'    => 'Regulation',
    'rf'      => $id,
    'fdb'     => 'funcgen', 
    'cl'      => $cell_line,  
  });
  return $href; 
}

sub title {
  my ($self, $f) = @_;
  my $id = $f->stable_id;
  my $type =$f->feature_type->name();
  if ($type =~/Promoter/){$type = 'Promoter_associated';}
  elsif ($type =~/Gene/){$type = 'Genic';}
  elsif ($type =~/Unclassified/){$type = 'Unclassified';}
  if ($type =~/Non/){$type = 'Non-genic';}
  my $pos = 'Chr ' .$f->seq_region_name .":". $f->start ."-" . $f->end;


 return "Regulatory Feature: $id; Type: $type; Location: $pos" ; 

}

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type) = @_;
  
  return $self->_render_text($feature, $feature_type, { 
    'headers' => [ 'id' ],
    'values' => [ $feature->stable_id ]
  });
}

1;
### Contact: Beth Pritchard bp1@sanger.ac.uk
