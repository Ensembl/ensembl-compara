package Bio::EnsEMBL::GlyphSet::cloneset;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "1mb cloneset"; }

## Retrieve all BAC map clones - these are the clones in the
## subset "bac_map" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_bac_map")

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_MiscFeatures( 'cloneset' );
}

## If bac map clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality...

### MISMATCH   RED
### DIFFERENT  GREY
### EMBL       BLUE
### ENSEMBL     GREEN
### ENSEMBL_NEW DARK GREEN
### GP          YELLOW
### SI_ENDSEQ   GOLD
### SKNIGHT     ORANGE
###             GREY

sub colour {
    my ($self, $f) = @_;
    my $type = $f->get_scalar_attribute('mismatch') ? 'MISMATCH' : 
               ($f->get_scalar_attribute('start_pos') eq $f->get_scalar_attribute('end_pos') ?
                $f->get_scalar_attribute('start_pos') : 'DIFFERENT');
    return $self->{'colours'}{"col_$type"}||'grey50', $self->{'colours'}{"lab_$type"}||'black', '';
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
    my ($self, $f ) = @_;
    return (qq(@{[$f->get_scalar_attribute('name')]}),'overlaid');
}

## Link back to this page centred on the map fragment

sub href {
    my ($self, $f ) = @_;
    return "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=@{[$f->get_scalar_attribute('name')]}";
}

sub tag {
    my ($self, $f) = @_; 
    my @result = (); 
    my $offset = $self->{'container'}->start - 1 ;
    unless( $f->get_scalar_attribute('mismatch') ) {
      if( $f->get_scalar_attribute('bac_start') < $f->seq_region_start ) {
        push @result, {
          'style' => 'underline',   'colour' => $self->{'colours'}{"seq_len"},
          'start' => $f->get_scalar_attribute('bac_start') - $offset, 'end'    => $f->seq_region_start
        }
      }
      if(  $f->get_scalar_attribute('bac_end') > $f->seq_region_end ) {
      if( $f->bac_end && $f->bac_end > $f->seq_end ) {
        push @result, {
          'style' => 'underline',   'colour' => $self->{'colours'}{"seq_len"},
          'start' => $f->seq_region_end,       'end'    => $f->get_scalar_attribute('bac_end') - $offset
        }
      }
    }
   if( $f->get_scalar_attribute('FISHmap') ) {
        push @result, {
	    'style' => 'left-triangle',
	    'colour' => $self->{'colours'}{"fish_tag"},
	}
   }
    return @result;
}
1;
__END__
## Create the zmenu...
## Include each accession id separately
sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( $self->check(), 'threshold_navigation' ) || 2e7) * 1000;
    my $zmenu = { 
        'caption' => "Clone: @{[$f->get_scalar_attribute('name')]}",
        "01:bp: @{[$f->seq_region_start]}-@{[$f->seq_region_end]}" => '',
        "02:length: @{[$f->length]} bps" => '',
        "03:Centre on clone:" => $self->href($f),
    };
    foreach(@{$f->get_all_attribute_values('synonyms')}) {
        $zmenu->{"11:Synonym: $_" } = '';
    }
    foreach($f->get_all_attribute_values('embl_accs')) {
        $zmenu->{"12:EMBL: $_" } = '';
    }
    (my $state = $f->get_scalar_attribute('state'))=~s/^\d\d://;
    $zmenu->{"13:Organisation: @{[$f->get_scalar_attribute('organisation')]}" } = '' if $f->get_scalar_attribute('organisation');
    $zmenu->{"14:State: $state"                                        } = '' if $state;
    $zmenu->{"15:Seq length: @{[$f->length]}"                          } = '' if $f->length;    
    $zmenu->{"16:FP length:  @{[$f->get_scalar_attribute('fp_size')]}"        } = '' if $f->get_scalar_attribute('fp_size');    
    $zmenu->{"17:super_ctg:  @{[$f->get_scalar_attribute('superctg')]}"       } = '' if $f->get_scalar_attribute('superctg');    
    $zmenu->{"18:FISH:  @{[$f->get_scalar_attribute('FISHmap')]}"             } = '' if $f->get_scalar_attribute('FISHmap');    
    $zmenu->{"70:Well:  @{[$f->get_scalar_attribute('location')]}"            } = '' if $f->get_scalar_attribute('location');    
    if( $f->get_scalar_attribute('start_pos') eq $f->get_scalar_attribute('end_pos') ) {
      $zmenu->{"80:Positioned by: @{[$f->get_scalar_attribute('start_pos')]}" } = '';
    } else {
      $zmenu->{"80:Start pos. by: @{[$f->get_scalar_attribute('start_pos')]}" } = '';
      $zmenu->{"81:End pos. by: @{[$f->get_scalar_attribute('end_pos')]}" }     = '';
    }
    if( $f->get_scalar_attribute('mismatch') ) { 
      $zmenu->{"90:Mismatch: @{[$f->get_scalar_attribute('mismatch')]}" } = '';
    } else {
      $zmenu->{"90:BAC start: @{[$f->get_scalar_attribute('bac_start')]}"     } = '' if( $f->get_scalar_attribute('bac_start') < $f->seq_region_start );
      $zmenu->{"91:BAC end: @{[$f->get_scalar_attribute('bac_end')]}"         } = '' if( $f->get_scalar_attribute('bac_end')   > $f->seq_region_end );
    }
   foreach( @{$f->get_all_attribute_values('bacends')} ) {
      $zmenu->{"18:BACend: $_" } = '';
    }
    $zmenu->{"30:Positioned by: @{[$f->get_scalar_attribute('positioned_by')]}" } = '' if($f->get_scalar_attribute('positioned_by'));    
    return $zmenu;
}

1;
