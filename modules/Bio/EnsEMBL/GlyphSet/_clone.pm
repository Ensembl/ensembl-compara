package Bio::EnsEMBL::GlyphSet::_clone;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label {
  my $self = shift;
  return $self->my_config( 'label' ) || 'Clones';
}

## Retrieve all BAC map clones - these are the clones in the
## subset "bac_map" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_bac_map")

sub _threshold_update {
  my $self = shift;
  my $thresholds = $self->my_config( 'threshold_array' )||{};
  my $container_length = $self->{'container'}->length();
  foreach my $th ( sort { $a<=>$b} keys %$thresholds ) {
    if( $container_length > $th * 1000 ) {
      foreach (keys %{$thresholds->{$th}}) {
        $self->set_my_config( $_, $thresholds->{$th}{$_} );
      }
    }
  }
}

sub features {
  my ($self) = @_;
  my $T = $self->my_config('FEATURES');
  my @T = split /\s+/,$T;

  my $db = $self->my_config('DATABASE');
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
## we aren't convinced on their quality...

sub colour {
    my ($self, $f) = @_;
    (my $state = $f->get_scalar_attribute('state')) =~ s/^\d\d://;
    my $to_colour = $f->get_scalar_attribute('inner_start') ? 'border' : $self->{'part_to_colour'};
    $to_colour = 'border' if ($f->length > $self->my_config('outline_threshold'));
    return $self->{'colours'}{"col_$state"}||$self->{'feature_colour'},
           $self->{'colours'}{"lab_$state"}||$self->{'label_colour'},
           $to_colour;
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
  my ($self, $f ) = @_;
  return ( $self->my_config('no_label')) ? q{}
	   : ($f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc)),'overlaid');
}

## Link back to this page centred on the map fragment

sub href {
  my ($self, $f ) = @_;
  my $name = $f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc));
  return "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?misc_feature=$name";
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
      'colour' => $f->{'_colour_flag'} || $self->{'colours'}{"col_$state"},
      'start'  => $s,
      'end'    => $e
    };
  }
  if( $f->get_scalar_attribute('fish') ) {
    push @result, {
      'style' => 'left-triangle',
      'colour' => $self->{'colours'}{"fish_tag"},
    };
  }
  push @result, {
    'style'  => 'right-end',
    'colour' => $self->{'colours'}{"bacend"}
  } if ( $bef == 2 || $bef == 3 );
  push @result, { 
    'style'=>'left-end',  
    'colour' => $self->{'colours'}{"bacend"}
  } if ( $bef == 1 || $bef == 3 );

  my $fp_size = $f->get_scalar_attribute('fp_size');
  if( $fp_size && $fp_size > 0 ) {
    my $start = int( ($f->start + $f->end - $fp_size)/2 );
    my $end   = $start + $fp_size - 1 ;
    push @result, {
      'style' => 'underline',
      'colour' => $self->{'colours'}{"seq_len"},
      'start'  => $start,
      'end'    => $end
    };
  }
  return @result;
}
## Create the zmenu...
## Include each accession id separately

sub zmenu {
	my ($self, $f ) = @_;
	return if $self->my_config('navigation') ne 'on';
	my $name = $f->get_first_scalar_attribute(qw(name well_name clone_name sanger_project synonym embl_acc alt_well_name bacend_well_nam));
		my $feature_type = 'Clone';
	my $position = 'bp';
	my $link_text = 'Centre on clone:';
	my $href =  $self->href($f);

	#change stuff for vega zfish haplotype scaffolds
	if ($self->my_config('FEATURES') eq 'hclone') {
		$feature_type = 'Haplotype Scaffold';
		$position = 'location',
		$link_text = 'View this scaffold';
		$href =~ s/misc_feature/l/;
		$href =~ s/:(\d+)$/-$1/;
	}
	
	my $zmenu = {
        qq(caption)                                                         => qq($feature_type: $name),
        qq(01:$position: @{[$f->seq_region_start]}-@{[$f->seq_region_end]}) => '',
        qq(02:length: @{[$f->length]} bps)                                  => '',
        qq(03:$link_text)                                                   => $href,
    };
    my @names = ( 
      [ 'name'           => '20:Name' ] ,
      [ 'well_name'      => '21:Well name' ],
      [ 'sanger_project' => '32:Sanger project' ],
      [ 'clone_name'     => '33:Library name' ],
      [ 'synonym'        => '34:Synonym' ],
      [ 'embl_acc'       => '35:EMBL accession', 'EMBL' ],
      [ 'bacend'         => '39:BAC end acc', 'EMBL' ],
      [ 'alt_well_name'    => '22:Well name' ],
      [ 'bacend_well_nam' => '31:BAC end well' ],
    );
    foreach my $ref (@names ) {
      foreach(@{$f->get_all_attribute_values($ref->[0])||[]}) {
        $zmenu->{"$ref->[1] $_" } = $ref->[2] ? $self->ID_URL( $ref->[2], $_ ) : '';
      }
    }
    (my $state = $f->get_scalar_attribute('state'))=~s/^\d\d://;
    my $bac_info = $f->get_scalar_attribute('BACend_flag');
    if($bac_info != '' ) {
      $bac_info = ('Interpolated', 'Start located', 'End located', 'Both ends located') [$bac_info];
    }

    $zmenu->{"41:HTGS_phase: @{[$f->get_scalar_attribute('htg')]}"}            = '' if $f->get_scalar_attribute('htg');
    $zmenu->{"42:Remark: @{[$f->get_scalar_attribute('remark')]}"}             = '' if $f->get_scalar_attribute('remark');

    $zmenu->{"43:Organisation: @{[$f->get_scalar_attribute('organisation')]}"} = '' if $f->get_scalar_attribute('organisation');

     my $state_link = '';
     $state_link = qq(http://www.sanger.ac.uk/cgi-bin/humace/clone_status?clone_name=).$f->get_scalar_attribute('synonym')
       if $state =~ /Committed|FinishAc|Accessioned/ &&
          $f->get_scalar_attribute('synonym') &&
          $f->get_scalar_attribute('organisation') eq 'SC';
    $zmenu->{"44:State: $state"                                         } = $state_link if $state;

    $zmenu->{"50:Seq length: @{[$f->get_scalar_attribute('seq_len')]}"  } = '' if $f->get_scalar_attribute('seq_len');
    $zmenu->{"50:FP length:  @{[$f->get_scalar_attribute('fp_size')]}"  } = '' if $f->get_scalar_attribute('fp_size');
    $zmenu->{"60:Super contig:  @{[$f->get_scalar_attribute('supercontig')]}" } = '' if $f->get_scalar_attribute('supercontig');
    $zmenu->{"70:BAC flags:  $bac_info"                          } = '' if $bac_info;
    $zmenu->{"75:FISH:  @{[$f->get_scalar_attribute('fish')]}"       } = '' if $f->get_scalar_attribute('fish');
  
    my $links = $self->my_config('LINKS');
    if( $links ) {
      my $Z = 80;
      foreach ( @$links ) {
        my $val = $f->get_scalar_attribute($_->[1]);
        next unless $val;
        (my $href = $_->[2]) =~ s/###ID###/$val/g;
        $zmenu->{"$Z:$_->[0]: $val"} = $href;
        $Z++;
      }
    }
    return $zmenu;
}

1;
