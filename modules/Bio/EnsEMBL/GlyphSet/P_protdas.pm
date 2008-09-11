package Bio::EnsEMBL::GlyphSet::P_protdas;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::ColourMap;
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::Glyph::Symbol::box; 
use POSIX; #floor

sub _init {
  my ($self) = @_;

  my $conf = $self->{'extras'};
  $self->{'pix_per_bp'}    = $self->{'config'}->transform->{'scalex'};
  my $prot_len      = $self->{'container'}->length;
  $conf->{'length'} = $prot_len;

# Check that we have features back and it's not a error message
  if (my @das_features = @{$conf->{features} || []}) {
    my $f = $das_features[0];
    if($f->das_type_id() eq '__ERROR__') {
      $self->errorTrack( 'Error retrieving '.$self->{'extras'}->{'label'}.' features ('.$f->das_id.')');
      return -1 ;   # indicates no features drawn because of DAS error
    }
  } else {
    $self->errorTrack( 'No positional '.$conf->{'label'}.' features in this region' );
    return 0;
  }

### If we display a genomic source (i.e features are chromosome based) then we need to 
### map them to the peptide
  if ($conf->{'source_type'} =~ /^ensembl_location/) {
    my $transcript = $self->{'container'}->adaptor->db->get_TranscriptAdaptor->fetch_by_translation_stable_id( $self->{'container'}->stable_id );
    my @features;
    foreach my $feat (@{$conf->{features}}) {
      my @coords =  grep { $_->isa('Bio::EnsEMBL::Mapper::Coordinate') } $transcript->genomic2pep($feat->das_segment->start, $feat->das_segment->end, $feat->strand);
      if (@coords) {
        my $c = $coords[0];
        my $end = ($c->end > $prot_len) ? $prot_len : $c->end; 
        $feat->das_end( $end );
        my $start = ($c->start < $end) ? $c->start : $end;
        $feat->das_start($start);
        push (@features, $feat);
      }
    }
    $conf->{features} = \@features;
  }

# Styles are returned as an array - we build a hash so it is easier to use ( probably should look into the fetching function ... ;)
  # hash styles by type
  my %styles;
  my $styles  = $conf->{'styles'};

  if( $styles && @$styles && $conf->{'use_style'} ) {
    my $styleheight = 0;
    foreach(@$styles) {
      $styles{$_->{'category'}}{$_->{'type'}} = $_ unless $_->{'zoom'};

      # Set row height ($configuration->{'h'}) from stylesheet
      # Currently, this uses the greatest height present in the stylesheet
      # but should really use the greatest height in the current featureset

      if (exists $_->{'attrs'} && exists $_->{'attrs'}{'height'}){
        my $tmpheight = $_->{'attrs'}{'height'};
        $tmpheight += abs $_->{'attrs'}{'yoffset'} if $_->{'attrs'}{'yoffset'} ;
        $styleheight = $tmpheight if $tmpheight > $styleheight;
      }
    }
    $conf->{'h'} = $styleheight if $styleheight;
    $conf->{'styles'} = \%styles;
  } else {
    $conf->{'use_style'} = 0;
  }

  if (my $chart = $conf->{'score'}){
    return $self->RENDER_colourgradient( $conf ) if ($chart eq 'c');
    return $self->RENDER_tilingarray( $conf )   if ($chart eq 's');
    return $self->RENDER_histogram( $conf )     if ($chart eq 'h');
  }
  return $self->RENDER_grouped($conf);
}

sub gmenu {
  my ($self, $f) = @_;
  my $desc = $f->das_feature_label() || $f->das_feature_id;
  my $zmenu = { 'caption' => $desc };
  if( my $m = $f->das_feature_id ){ $zmenu->{"03:ID: $m"}     = undef }
  if( my $m = $f->das_type       ){ $zmenu->{"05:TYPE: $m"}   = undef }
  if( my $m = $f->das_method     ){ $zmenu->{"10:METHOD: $m"} = undef }
  my $ids = 15;
  my $href;
  foreach my $dlink ($f->das_links) {
    my $txt = $dlink->{'txt'} || $dlink->{'href'};
    my $dlabel = sprintf("%02d:LINK: %s", $ids++, $txt);
    $zmenu->{$dlabel} = $dlink->{'href'};
    $href =  $dlink->{'href'} if (! $href);
  }
  if( my $m = $f->das_note       ) { 
    if (ref $m eq 'ARRAY') {
	foreach my $n (@$m) {
	  $zmenu->{"$ids:NOTE: $n"}   = undef;
	  $ids++;
	}
     } else {
	$zmenu->{"40:NOTE: $m"}   = undef;
     }
  }
	
  return $zmenu;
}

#----------------------------------------------------------------------
# Returns the order corresponding to this glyphset
sub managed_name{
  my $self = shift;
  return $self->{'extras'}->{'order'} || 0;
}


sub zmenu {
  my ($self, $f) = @_;
  my $desc = $f->das_feature_label() || $f->das_feature_id;
  my $zmenu = { 'caption' => $desc };
  if( my $m = $f->das_score){ $zmenu->{"20:SCORE: $m"}     = undef }
  my $ids = 50;
  my $href;
  foreach my $dlink ($f->das_links) {
    my $txt = $dlink->{'txt'} || $dlink->{'href'};
    my $dlabel = sprintf("%02d:LINK: %s", $ids++, $txt);
    $zmenu->{$dlabel} = $dlink->{'href'};
    $href =  $dlink->{'href'} if (! $href);
  }
if( my $m = $f->das_note       ) {
    if (ref $m eq 'ARRAY') {
        foreach my $n (@$m) {
          $zmenu->{"$ids:NOTE: $n"}   = undef;
          $ids++;
        }
     } else {
        $zmenu->{"40:NOTE: $m"}   = undef;
     }
  }
  return $zmenu;
}

# Function will display DAS features with variable height depending on SCORE attribute
sub RENDER_histogram {
  my( $self, $configuration ) = @_;

  my @features = sort { $a->das_start() <=> $b->das_start() } @{$configuration->{'features'} || []};
  my ($min_score, $max_score) = (sort {$a <=> $b} (map { $_->score } @features))[0,-1];
  my $style;

  my $row_height = $configuration->{'h'} || 30;
  my $pix_per_score = ($max_score - $min_score) / $row_height;
  my $bp_per_pix = 1 / $self->{pix_per_bp};

  $configuration->{h} = $row_height;

  my ($gScore, $gWidth, $fCount, $gStart, $mScore) = (0, 0, 0, 0, $min_score);
  for (my $i = 0; $i< @features; $i++) {
    my $f = $features[$i];

    # keep within the window we're drawing
    my $START = $f->das_start() < 1 ? 1 : $f->das_start();
    my $END   = $f->das_end()   > $configuration->{'length'}  ? $configuration->{'length'} : $f->das_end();
    my $width = ($END - $START +1);

    my $score = $f->das_score;
    $score = $max_score if ($score > $max_score);
    $score = $min_score if ($score < $min_score);

# Here we "group" features if they are too small and located very close to each other ..

    $gWidth += $width;
    $gScore += $score;
    $mScore = $score if ($score > $mScore);
    $fCount ++;
    $gStart = $START if ($fCount == 1);
# If feature is smaller than 1px and next feature is closer than 1px then we merge features ..
# 1px value depend on the zoom ..
    if ($gWidth < $bp_per_pix) {
      my $nf = $features[$i+1];
      if ($nf) {
        my $distance = $nf->das_start() - $END;
        next if ($distance < $bp_per_pix);
      }
    }
    my $height;
    if (lc($configuration->{'fg_merge'}) eq 'a') { # get the average value
      $height = ($gScore / $fCount - $min_score) / $pix_per_score;
     } else { # get the max value
      $height = ($mScore - $min_score) / $pix_per_score;
      if ($height < 0) {
        warn("ERROR: !! $mScore * $min_score * $pix_per_score");
      }
    }
    my ($zmenu );
    my $Composite = $self->Composite({
      'y'         => 0,
      'x'         => $START-1,
      'absolutey' => 1,
    });

    if ($fCount > 1) {
      $zmenu = {
        'caption'         => $configuration->{'label'},
      };
      $zmenu->{"03:$fCount features merged"} = '';
      $zmenu->{"05:Average SCORE: ".($gScore/$fCount)} = '';
      $zmenu->{"08:Max SCORE: $mScore"} = '';
      $zmenu->{"10:START: $gStart"} = '';
      $zmenu->{"20:END: $END"} = '';
    } else {
      $zmenu = $self->zmenu( $f );
    }
    $Composite->{'zmenu'} = $zmenu;

    my $y_offset = $row_height - $height;
    my $style = $self->get_featurestyle($f, $configuration);
    my $fdata = $self->get_featuredata($f, $configuration, $y_offset);

    my $symbol = Bio::EnsEMBL::Glyph::Symbol::box->new($fdata, $style->{'attrs'});
    $symbol->{'style'}->{'height'} = $height;

    $Composite->push($symbol->draw);
    $self->push( $Composite );

    $gWidth = $gScore = $fCount = 0;
    $mScore = $min_score;
  } # END loop over features

  return 1;
}   # END RENDER_histogram

# Function will display DAS features with variable height depending on SCORE attribute
# Similar to histogram but allows for negative values and will highlight pick values, i.e
# when 2 or more features are merged due to resolution the highest score will be used to determine the feature height
# Probably should merge with histogram as they are very similar

sub RENDER_tilingarray{
  my( $self, $configuration ) = @_;
  
  my @features = sort { $a->das_score <=> $b->das_score  } @{$configuration->{'features'}};
  my ($min_score, $max_score) = ($features[0]->das_score || 0, $features[-1]->das_score || 0);
  my $style;

  my @positive_features = grep { $_->das_score >= 0 } @features;
  my @negative_features = grep { $_->das_score < 0 } reverse @features;

  my $row_height = $configuration->{'h'} || 30;
  my $pix_per_score = (abs($max_score) >  abs($min_score) ? abs($max_score) : abs($min_score)) / $row_height;
  my $bp_per_pix = 1 / $self->{pix_per_bp};
  $configuration->{h} = $row_height;

  my ($gScore, $gWidth, $fCount, $gStart, $mScore) = (0, 0, 0, 0, $min_score);

# Draw the axis

  $self->push( $self->Line({
    'x'         => 0,
    'y'         => $row_height + 1,
    'width'     => $configuration->{'length'},
    'height'    => 0,
    'absolutey' => 1,
    'colour'    => 'red',
    'dotted'    => 1,
  }));

  $self->push( $self->Line({
    'x'         => 0,
    'y'         => 0,
    'width'     => 0,
    'height'    => $row_height * 2 + 1,
    'absolutey' => 1,
    'absolutex' => 1,
    'colour'    => 'red',
    'dotted'    => 1,
  }));

  foreach my $f (@negative_features, @positive_features) {
    my $START = $f->das_start() < 1 ? 1 : $f->das_start();
    my $END   = $f->das_end()   > $configuration->{'length'}  ? $configuration->{'length'} : $f->das_end();
    my $width = ($END - $START +1);
    my $score = $f->das_score || 0;

    my $Composite = $self->Composite({
      'y'         => 0,
      'x'         => $START-1,
      'absolutey' => 1,
    });

    my $height = abs($score) / $pix_per_score;
    my $y_offset =     ($score > 0) ?  $row_height - $height : $row_height+2;
    $y_offset-- if (! $score);

    my $zmenu = $self->zmenu( $f );
    $Composite->{'zmenu'} = $zmenu;

    # make clickable box to anchor zmenu
    $Composite->push( $self->Space({
      'x'         => $START - 1,
      'y'         => ($score ? (($score > 0) ? 0 : ($row_height + 2)) : ($row_height + 1)),
      'width'     => $width,
      'height'    => $score ? $row_height : 1,
      'absolutey' => 1
    }) );

    my $style = $self->get_featurestyle($f, $configuration);
    my $fdata = $self->get_featuredata($f, $configuration, $y_offset);

    my $symbol = Bio::EnsEMBL::Glyph::Symbol::box->new($fdata, $style->{'attrs'});
    $symbol->{'style'}->{'height'} = $height;

    $Composite->push($symbol->draw);
    $self->push( $Composite );
  } # END loop over features

 return 1;
}   # END RENDER_tilingarray


# Function will display DAS features in different colour with depending on SCORE attribute
sub RENDER_colourgradient {
  my ($self, $configuration) = @_; 

  my $bp_per_pix = 1 / $self->{pix_per_bp};
  my @features = sort { $a->das_score <=> $b->das_score } @{$configuration->{'features'} || []};
  my ($min_value, $max_value) = $configuration->{'fg_data'} eq 'n' ? ($configuration->{'fg_min'}, $configuration->{fg_max}): ($features[0]->das_score || 0, $features[-1]->das_score || 0);
  my ($min_score, $max_score) = $configuration->{'fg_data'} eq 'n' ? (0, 100): ($min_value, $max_value);

  $configuration->{'fg_grades'} ||= 20;

  my $score_range = $max_value - $min_value;
  my $score_per_grade =  ($max_score - $min_score)/ $configuration->{'fg_grades'};
  my $cm = new Sanger::Graphics::ColourMap;
  my @cg = $cm->build_linear_gradient($configuration->{'fg_grades'}, ['yellow', 'green', 'blue']);
  my $style;
 
# To make sure that the features with lowest and highest scores get displayed
  push @features, $features[0];
  push @features, $features[-2];

  my $y_offset =     0;

  my $row_height = $configuration->{'h'} || 20;
  $configuration->{h} = $row_height;

 foreach my $f (@features) {
    my $START = $f->das_start() < 1 ? 1 : $f->das_start();
    my $END   = $f->das_end()   > $configuration->{'length'} ? $configuration->{'length'} : $f->das_end();
    my $width = ($END - $START +1);
    my $score = $configuration->{'fg_data'} eq 'n' ? ((($f->das_score || 0) - $min_value) * 100 / $score_range) : ($f->das_score || 0);

    if ($score < $min_value) {
      $score = $min_value;
    } elsif ($score > $max_value) {
      $score = $max_value;
    }
    my $Composite = $self->Composite({
      'y'         => 0,
      'x'         => $START-1,
      'absolutey' => 1,
    });

    my $grade = ($score >= $max_score) ? $configuration->{'fg_grades'} - 1 : int(($score - $min_score) / $score_per_grade);
    $grade = 0 if ($grade < 0);
    my $col = $cg[$grade];

    my $zmenu = $self->zmenu($f);
    $Composite->{'zmenu'} = $zmenu;

    # make clickable box to anchor zmenu
    $Composite->push( $self->Space({
      'x'         => $START - 1,
      'y'         => 0,
      'width'     => $width,
      'height'    => $row_height,
      'absolutey' => 1
    }) );

    my $style = $self->get_featurestyle($f, $configuration);
    my $fdata = $self->get_featuredata($f, $configuration, $y_offset);

    my $symbol = Bio::EnsEMBL::Glyph::Symbol::box->new($fdata, $style->{'attrs'});
    $style->{'attrs'}{'colour'} = $col;

    $Composite->push($symbol->draw);
    $self->push( $Composite );
  } # END loop over features

  return 1;
}   # END RENDER_colourgradient


# Function will display DAS features grouped by feature id ( which is wrong ! DAS spec demands unique feature id! )
# Need to talk to das source maintainers first to convience them to update das sources to comply with DAS spec

sub RENDER_grouped {
  my ($self, $configuration) = @_; 
  my $Config        = $self->{'config'};
  my @bitmap        = undef;
  my $prot_len      = $configuration->{'length'};
  my $pix_per_bp    = $self->{'pix_per_bp'};
  my $bitmap_length = floor( $prot_len * $pix_per_bp);

  my $y             = 0;
  my $h             = $configuration->{'h'} || 4;
  $configuration->{'h'} = $h;

  my $fhash;

  $self->_init_bump;

  foreach my $f (@{$self->{extras}->{features}}) {
# Create a new composite and put the feature there
    my $Composite = $self->Composite({
      'x'     => $f->start,
      'y'     => $y,
      'zmenu' => $self->gmenu($f),
    });

    my $style = $self->get_featurestyle($f, $configuration);
    my $fdata = $self->get_featuredata($f, $configuration, 0);
    my $symbol = $self->get_symbol($style, $fdata);
#    my $symbol = Bio::EnsEMBL::Glyph::Symbol::box->new($fdata, $style->{'attrs'});
   
   $Composite->push($symbol->draw);

# Now check that the new feature does not overlap any preceeding features
# If it does than 'bump' the row, i.e move the composite down to the next row

    my $bump_start = floor($Composite->x() * $pix_per_bp);
    next if ($bump_start > $bitmap_length);
    my $bump_end = $bump_start + floor($Composite->width()*$pix_per_bp);
    my $row = $self->bump_row( $bump_start, $bump_end );
    );
    $Composite->y($Composite->y() + $row * ($h + 2) );
    $self->push($Composite);

# Now to the bit that always was in Ensembl but does not comply with DAS spec, namely grouping features by feature id.
# need to address the issue to make sure we comply with DAS spec
# meantime we put a line between features that have same id and reside on the same row in the bitmap

    my $key = join('*', $row,$f->das_feature_id); 
    if (my $ox = $fhash->{$key}) {
      my $rect = $self->Rect({
         'x'         => $ox,
         'y'         => 2,
         'width'     => $f->start - $ox,
         'height'    => 0,
         'colour'    => $style->{'attrs'}{'colour'},
         'absolutey' => 1,
      });
      $Composite->push($rect);
    }

    $fhash->{$key} = $f->end;
  }
}


1;

