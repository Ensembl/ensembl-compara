package Bio::EnsEMBL::GlyphSet::_oligo;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(Bio::EnsEMBL::GlyphSet::_alignment);

sub features { 
  my ($self) = @_;
  my $slice = $self->{'container'};
  
  my $fg_db = undef;
  my $db_type  = $self->my_config('db_type')||'funcgen';
  unless($self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $fg_db = $self->{'container'}->adaptor->db->get_db_adaptor($db_type);
    if(!$fg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }; 
  my $probe_feature_adaptor = $fg_db->get_ProbeFeatureAdaptor();

  $self->timer_push( 'Preped'); 
  my ($vendor_name, $array_name ) = split (/__/, $self->my_config('array')); 
  my $T = $probe_feature_adaptor->fetch_all_by_Slice_array_vendor( $slice, $array_name, $vendor_name );
  $self->timer_push( 'Retrieved oligos', undef, 'fetch' );
  return ( $self->my_config('array') => [$T] );
}

sub feature_group {
  my( $self, $f ) = @_; 
  next unless ( $f && $f->isa('Bio::EnsEMBL::Funcgen::ProbeFeature'));
  my ($vendor_name, $array_name ) = split (/__/, $self->my_config('array')); 
  if ( $f->probeset_id) { 
    return $f->probe->probeset->name;
  } else { 
    return $f->probe->get_probename($array_name);
  }  
}

sub feature_label {
  my( $self, $f ) = @_;
  return $self->feature_group($f);
}

sub feature_title {
  my( $self, $f ) = @_; 
  return $self->feature_group($f);
}

sub href {
### Links to /Location/Genome with type of 'ProbeFeature'
  my ($self, $f ) = @_;
  my ($vendor, $array_name ) = split (/__/, $self->my_config('array'));
  my ($probe_name, $probe_type);
  if ( $f->probeset_id) {
    $probe_name = $f->probe->probeset->name;
    $probe_type = 'pset';
  } else { 
    $probe_name = $f->probe->get_probename($array_name);
    $probe_type = 'probe';
  }  

  return $self->_url({
    'type' => 'Location',
    'action' => 'Oligo',
    'fdb'    => 'funcgen',
    'ftype'  => 'ProbeFeature',
    'id'     => $probe_name,
    'ptype'  => $probe_type,
    'array'  => $array_name,
  }); 
}

sub export_feature {
  my $self = shift;
  my ($feature, $source) = @_;
  return; 
#  return $self->_render_text($feature, 'Oligo', {
#    'headers' => [ 'probeset' ],
#    'values' => [ $feature->can('probeset') ? $feature->probeset : '' ]
#  }, { 'source' => $source });
}

sub draw_cigar_feature {
  my ($self, $params) = @_;

  my ($composite, $f, $h) = map $params->{$_}, qw(composite feature height);

  $f = Bio::EnsEMBL::DnaDnaAlignFeature->new( 
    -slice  => $f->slice, 
    -start  => $f->start,
    -end    => $f->end, 
    -strand => $self->strand,
    -hstart => $f->start, 
    -hend   => $f->end,  
    -cigar_string => $f->cigar_string
  );
  
  my $length  = $self->{'container'}->length;
  my $cigar;

  eval { $cigar = $f->cigar_string; };

  if ($@ || !$cigar) {
    my ($s, $e) = ($f->start, $f->end);
    $s = 1 if $s < 1;
    $e = $length if $e > $length;

    $composite->push($self->Rect({
      x         => $s - 1,
      y         => 0,
      width     => $e - $s + 1,
      height    => $h,
      colour    => $params->{'feature_colour'},
      absolutey => 1
    }));

    return;
  }

  my $strand  = $self->strand;
  my $fstrand = $f->strand;
  my $hstrand = $f->can('hstrand') ? $f->hstrand : undef;
  my ($start, $hstart, $hend);
  my @delete;

  if ($self->isa('Bio::EnsEMBL::GlyphSet::_oligo')) {
    my $o   = $params->{'do_not_flip'} ? 1 : $strand;
    $start  = $o == 1 ? $f->start : $f->end;
    $hstart = $o == 1 ? $f->hstart : $f->hend;
    $hend   = $o == 1 ? $f->hend : $f->hstart;
  } else {
    $start  = $f->start;
    $hstart = $f->hstart;
    $hend   = $f->hend;
  }

 my ($slice_start, $slice_end, $tag1, $tag2);

  if ($f->slice) {
    $slice_start = $f->slice->start;
    $slice_end   = $f->slice->end;
    $tag1        = join ':', $f->species, $f->slice->seq_region_name;
    $tag2        = join ':', $f->hspecies, $f->hseqname;
  } else {
    $slice_start = $f->seq_region_start;
    $slice_end   = $f->seq_region_end;
    $tag1        = $f->seqname;
  }

  # Parse the cigar string, splitting up into an array
  # like ('10M','2I','30M','I','M','20M','2D','2020M');
  # original string - "10M2I30MIM20M2D2020M"
  my @cigar = $f->cigar_string =~ /(\d*[MDImUXS=.])/g;
  @cigar = reverse @cigar if $fstrand == -1;


  foreach (@cigar) {
    # Split each of the {number}{Letter} entries into a pair of [ {number}, {letter} ]
    # representing length and feature type ( 'M' -> 'Match/mismatch', 'I' -> Insert, 'D' -> Deletion )
    # If there is no number convert it to [ 1, {letter} ] as no-number implies a single base pair...
    my ($l, $type) = /^(\d+)([MDImUXS=])/ ? ($1, $2) : (1, $_);

    # If it is a D (this is a deletion) and so we note it as a feature between the end
    # of the current and the start of the next feature (current start, current start - ORIENTATION)
    # otherwise it is an insertion or match/mismatch
    # we compute next start sa (current start, next start - ORIENTATION)
    # next start is current start + (length of sub-feature) * ORIENTATION
    my $s = $start;
    my $e = ($start += ($type eq 'D' ? 0 : $l)) - 1;

    my $s1 = $fstrand == 1 ? $slice_start + $s - 1 : $slice_end - $e + 1;
    my $e1 = $fstrand == 1 ? $slice_start + $e - 1 : $slice_end - $s + 1;

    my ($hs, $he);

    if ($fstrand == 1) {
      $hs = $hstart;
      $he = ($hstart += ($type eq 'I' ? 0 : $l)) - 1;
    } else {
      $he = $hend;
      $hs = ($hend -= ($type eq 'I' ? 0 : $l)) + 1;
    }
    # If a match/mismatch - draw box
    if ($type =~ /^[MmU=X]$/) {
      ($s, $e) = ($e, $s) if $s > $e; # Sort out flipped features

      next if $e < 1 || $s > $length; # Skip if all outside the box

      $s = 1       if $s < 1;         # Trim to area of box
      $e = $length if $e > $length;

      my $box = $self->Rect({
        x         => $s - 1,
        y         => 0,
        width     => $e - $s + 1,
        height    => $h,
        colour    => $params->{'feature_colour'},
        absolutey => 1
      });

      if ($params->{'link'}) {
        my $tag = $strand == 1 ? "$tag1:$s1:$e1#$tag2:$hs:$he" : "$tag2:$hs:$he#$tag1:$s1:$e1";
        my $x;

        if ($params->{'other_ori'} == $hstrand && $params->{'other_ori'} == 1) {
          $x = $strand == -1 ? 0 : 1; # Use the opposite value to normal to ensure alignments which are between different orientations by default do not display a cross-over join
        } else {
          $x = $strand == -1 ? 1 : 0;
        }
        $x ||= 1 if $fstrand == 1 && $hstrand * $params->{'other_ori'} == -1; # the feature has been flipped, so force x to the same value each time to achieve a cross-over join

        $self->join_tag($box, $tag, {
          x     => $x,
          y     => $strand == -1 ? 1 : 0,
          z     => $params->{'join_z'},
          col   => $params->{'join_col'},
          style => 'fill'
        });

        $self->join_tag($box, $tag, {
          x     => !$x,
          y     => $strand == -1 ? 1 : 0,
          z     => $params->{'join_z'},
          col   => $params->{'join_col'},
          style => 'fill'
        });
      }

      $composite->push($box);
    } elsif ($type eq 'D') { # If a deletion temp store it so that we can draw after all matches
      ($s, $e) = ($e, $s) if $s < $e;

      next if $e < 1 || $s > $length || $params->{'scalex'} < 1 ;  # Skip if all outside box

      push @delete, $e;
    }
  }

  # Draw deletion markers
  foreach (@delete) {
    $composite->push($self->Rect({
      x         => $_,
      y         => 0,
      width     => 0,
      height    => $h,
      colour    => $params->{'delete_colour'},
      absolutey => 1
    }));
  }
}

1
