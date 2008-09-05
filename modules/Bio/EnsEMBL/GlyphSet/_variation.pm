package Bio::EnsEMBL::GlyphSet::_variation;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

use Bio::EnsEMBL::Variation::VariationFeature;


sub my_label { return "SNPs"; }

sub features {
  my ($self) = @_;
  my $max_length    = $self->my_config( 'threshold' )  || 1000;
  my $slice_length  = $self->{'container'}->length;
  if($slice_length > $max_length*1010) {
    $self->errorTrack('Variation features not displayed for more than '.$max_length.'Kb');
    return;
  }
  return $self->fetch_features;
}

sub check_source {
  my ($self,$f,$sources) = @_;
  foreach ( @{$f->get_all_sources} ) {
    return 1 if $sources->{$_};
  }
  return 0;
}

sub features {
  my ($self) = @_;
  my $max_length    = $self->my_config( 'threshold' )  || 1000;
  my $slice_length  = $self->{'container'}->length;
  if($slice_length > $max_length*1010) {
    $self->errorTrack('Variation features not displayed for more than '.$max_length.'Kb');
    return;
  }

  unless( $self->cache( $self->{'my_config'}->key ) ) {
    my $sources = $self->my_config('sources');
       $sources = { map { ($_,1) } @$sources } if $sources;
    my %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;

## Add a filtering step here...
    warn "SNP filter... ",$self->my_config('filter');
    my @vari_features =
      map  { $_->[1] }              ## Quick indexing schwartzian transform
      sort { $a->[0] <=> $b->[0] }  ## to make sure that "most functional" snps appear first!
      map  { [ $ct{$_->display_consequence} * 1e9 + $_->start, $_ ] }
      grep { $sources ? $self->check_source($_,$sources) : 1 } ## If sources filter by source!!
      grep { $_->map_weight < 4 }
      @{ $self->{'container'}->get_all_VariationFeatures($self->my_config('filter')) || [] };
    $self->cache( $self->{'my_config'}->key, \@vari_features );
  }
  my $snps = $self->cache( $self->{'my_config'}->key ) || [];

  if(0&&@$snps) {
    $self->_add_legend( 'variations_legend', $self->_pos );
    my %T = ();
    foreach my $f (@$snps) {
      my $x = $f->consequence_type;
      next if $T{$x};
      $self->legend_add(
        'variations_legend',
        $self->my_colour( $x ),
        $self->my_colour( $x, 'text' )
      );
      $T{$x}=1;
    }
  }
  return $snps;
}

sub colour_key {
  my ($self, $f) = @_;
  return lc($f->display_consequence);
}

sub href {
  my $self = shift;
  my $f    = shift;
  my $view = shift || 'snpview';
  my $pops;

  if ($view eq 'ldview') {
    my $Config   = $self->{'config'};
    my $config_pop = $Config->{'_ld_population'};
    
    return unless $config_pop;
    foreach ( @$config_pop ) {
      $pops .= "pop=$_;";
    }
  }

  my $id     = $f->variation_name;
  my $source = $f->source;
  my ($species, $start, $region, $oslice);

  if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
      ($oslice, $start)  = $self->{'container'}->get_original_seq_region_position( $f->{start} );
      $region = $oslice->seq_region_name();
      ($species = $self->{container}->genome_db->name) =~ s/ /_/g;
      
  } else {
      $start  = $self->slice2sr( $f->start, $f->end );
      $region = $self->{'container'}->seq_region_name();
      $species = "@{[$self->{container}{web_species}]}";
  }

  return "/$species/$view?snp=$id;source=$source;c=$region:$start;w=20000;$pops";

  return $self->_url( );
}

sub title {

}

sub feature_label {
  my ($self, $f) = @_;
  my $ambig_code = $f->ambig_code;
  my @T = $ambig_code eq '-' ? undef : ($ambig_code,'overlaid');
  return @T;
}

sub tag {
  my ($self, $f) = @_;
  if( $self->my_config('style') eq 'box' ) {
    my $style = $f->start > $f->end       ? 'left-snp'
              : $f->var_class eq 'in-del' ? 'delta'
              : 'box'
              ;
    my $letter = $style eq 'box' ? $f->ambig_code : "";
    my $CK = $self->colour_key($f);
    return {
      'style'        => $style,
      'colour'       => $self->my_colour( $CK ),
      'letter'       => $style eq 'box' ? $f->ambig_code : "",
      'label_colour' => $self->my_config( $CK, 'label' )
    };
  }
  if($f->start > $f->end ) {    
    my $consequence_type = lc($f->display_consequence);
    return ( { 'style' => 'insertion', 'colour' => $self->my_colour($consequence_type) } );
  }
}

sub highlight {
  my $self = shift;
  my ($f, $composite, $pix_per_bp, $h, $hi_colour) = @_;
  return if $self->my_config('style') ne 'box';
  ## Get highlights...
  my %highlights;
  @highlights{$self->highlights()} = ();

  # Are we going to highlight self item...
  my $id = $f->variation_name();
  $id =~ s/^rs//;
  return unless $highlights{$id} || $highlights{'rs'.$id};
  $self->unshift( $self->Rect({  # First a white box!
    'x'         => $composite->x() - 1/$pix_per_bp,
    'y'         => $composite->y(),  ## + makes it go down
    'width'     => $composite->width() + 2/$pix_per_bp,
    'height'    => $h + 2,
    'colour'    => "white",
    'absolutey' => 1,
  }),$self->Rect({ # Then a 1 pixel bigger black box...!
    'x'         => $composite->x() -2/$pix_per_bp,
    'y'         => $composite->y() -1,  ## + makes it go down
    'width'     => $composite->width() + 4/$pix_per_bp,
    'height'    => $h + 4,
    'colour'    => $hi_colour,
    'absolutey' => 1,
  }));
}

1;
