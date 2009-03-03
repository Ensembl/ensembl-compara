package Bio::EnsEMBL::GlyphSet::_clone;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

## Retrieve all BAC map clones - these are the clones in the
## subset "bac_map" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_bac_map")

sub features {
  my ($self) = @_;
  my $db = $self->my_config('db');
  my $misc_sets = $self->my_config('set');
  my @T = ($misc_sets);

  my @sorted =  
    map { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map { [$_->seq_region_start - 
      1e9 * (
      $_->get_scalar_attribute('state') + $_->get_scalar_attribute('BACend_flag')/4
      ), $_]
    }
    map { @{$self->{'container'}->get_all_MiscFeatures( $_, $db )||[]} } @T;
  return \@sorted;
}

## If bac map clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality... However draw ENCODE filled

sub get_colours {
  my( $self, $f ) = @_;
  my $T = $self->SUPER::get_colours( $f );
  if( ! $self->my_colour( $T->{'key'}, 'solid' ) ) {
    $T->{'part'} = 'border' if $f->get_scalar_attribute('inner_start');
    $T->{'part'} = 'border' if ($self->my_config('outline_threshold') && ($f->length > $self->my_config('outline_threshold')) );
  }
  return $T;
}

sub colour_key {
  my ($self, $f) = @_;
  (my $state = $f->get_scalar_attribute('state')) =~ s/^\d\d://;
  return lc( $state ) if $state;
  my $flag = 'default';
  if( $self->my_config('set','alt') ) {
    $flag = $self->{'flags'}{$f->dbID} ||= $self->{'flag'} = ($self->{'flag'} eq 'default' ? 'alt' : 'default');
  }
  return ( $self->my_config('set'), $flag );
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub feature_label {
  my ($self, $f ) = @_;
  return  ( $self->my_config('no_label')) 
        ? ()
	: ($f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc)),'overlaid')
        ;
}

## Link back to this page centred on the map fragment
sub href {
  my ($self, $f ) = @_;
  my $db = $self->my_config('db');
  my $name = $f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc));
  my $mfid = $f->dbID;
  my $r = $f->seq_region_name.':'.$f->seq_region_start.'-'.$f->seq_region_end;
  my $zmenu = {
      'type'        =>'Location',
      'action'      =>'View',
      'r'           =>$r,
      'misc_feature_n'=>$name,
      'mfid'        =>$mfid,
      'db'          => $db,
  };
  return $self->_url($zmenu);
}

sub tag {
  my ($self, $f) = @_; 
  my @result = (); 
  my $bef = $f->get_scalar_attribute('BACend_flag');
  (my $state = $f->get_scalar_attribute('state')) =~ s/^\d\d://;
  my ($s,$e) = $self->sr2slice( $f->get_scalar_attribute('inner_start'), $f->get_scalar_attribute('inner_end') );
  if( $s && $e ){
    push @result, {
      'style'  => 'rect',
      'colour' => $f->{'_colour_flag'} || $self->my_colour($state),
      'start'  => $s,
      'end'    => $e
    };
  }
  if( $f->get_scalar_attribute('fish') ) {
    push @result, {
      'style' => 'left-triangle',
      'colour' => $self->my_colour('fish_tag'),
    };
  }
  push @result, {
    'style'  => 'right-end',
    'colour' => $self->my_colour('bacend'),
  } if ( $bef == 2 || $bef == 3 );
  push @result, { 
    'style'=>'left-end',  
    'colour' => $self->my_colour('bacend'),
  } if ( $bef == 1 || $bef == 3 );

  my $fp_size = $f->get_scalar_attribute('fp_size');
  if( $fp_size && $fp_size > 0 ) {
    my $start = int( ($f->start + $f->end - $fp_size)/2 );
    my $end   = $start + $fp_size - 1 ;
    push @result, {
      'style' => 'underline',
      'colour' => $self->my_colour('seq_len'),
      'start'  => $start,
      'end'    => $end
    };
  }
  return @result;
}

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type) = @_;
  
  return $self->_render_text($feature, $feature_type, { 
    'headers' => [ 'id' ],
    'values' => [ [$self->feature_label($feature)]->[0] ]
  });
}


## Create the zmenu...
## Include each accession id separately

1;
