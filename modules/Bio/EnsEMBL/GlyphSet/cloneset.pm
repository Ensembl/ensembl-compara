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
    return $self->{'container'}->get_all_MapFrags( 'cloneset' );
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
    my $type = !$f->bac_start ? 'EMBL' : 
                (  $f->mismatch() ? 'MISMATCH' : 
                 ( $f->start_pos eq $f->end_pos ? $f->start_pos : 'DIFFERENT') );
    return $self->{'colours'}{"col_$type"}||'grey50', $self->{'colours'}{"lab_$type"}||'black', '';
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
    my ($self, $f ) = @_;
    return ($f->name,'overlaid');
}

## Link back to this page centred on the map fragment

sub href {
    my ($self, $f ) = @_;
    return "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=".$f->name
}

sub tag {
    my ($self, $f) = @_; 
    my @result = (); 
    unless( $f->mismatch ) {
      if( $f->bac_start && $f->bac_start < $f->seq_start ) {
        push @result, {
          'style' => 'underline',   'colour' => $self->{'colours'}{"seq_len"},
          'start' => $f->bac_start - $f->seq_start + $f->start, 'end'    => $f->start
        }
      }
      if( $f->bac_end && $f->bac_end > $f->seq_end ) {
        push @result, {
          'style' => 'underline',   'colour' => $self->{'colours'}{"seq_len"},
          'start' => $f->end,       'end'    => $f->bac_end - $f->seq_start + $f->start
        }
      }
    }
   if( $f->FISHmap ) {
        push @result, {
	    'style' => 'left-triangle',
	    'colour' => $self->{'colours'}{"fish_tag"},
	}
   }
    return @result;
}
## Create the zmenu...
## Include each accession id separately

sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( $self->check(), 'threshold_navigation' ) || 2e7) * 1000;
    my $zmenu = { 
        'caption' => "Clone: ".$f->name,
        '01:bp: '.$f->seq_start."-".$f->seq_end => '',
        '02:length: '.$f->length.' bps' => '',
        '03:Centre on clone:' => $self->href($f),
    };
    foreach($f->synonyms) {
        $zmenu->{"11:Synonym: $_" } = '';
    }
    foreach($f->embl_accs) {
        $zmenu->{"12:EMBL: $_" } = '';
    }
    (my $state = $f->state)=~s/^\d\d://;
    $zmenu->{'13:Organisation: '.$f->organisation} = '' if($f->organisation);
    $zmenu->{"14:State: $state"        } = ''              if($f->state);
    $zmenu->{'15:Seq length: '.$f->seq_len } = ''        if($f->seq_len);    
    $zmenu->{'16:FP length:  '.$f->fp_size } = ''        if($f->fp_size);    
    $zmenu->{'17:super_ctg:  '.$f->superctg} = ''        if($f->superctg);    
    $zmenu->{'18:FISH:  '.$f->FISHmap } = ''        if($f->FISHmap);    
    $zmenu->{'70:Well:  '.$f->location } = ''        if($f->location);    
    if( $f->start_pos eq $f->end_pos ) {
      $zmenu->{'80:Positioned by: '.$f->start_pos} = '';
    } else {
      $zmenu->{'80:Start pos. by: '.$f->start_pos} = '';
      $zmenu->{'81:End pos. by: '.$f->end_pos} = '';
    }
    if( $f->mismatch ) { 
      $zmenu->{'90:Mismatch: '.$f->mismatch } = '';
    } else {
      $zmenu->{'90:BAC start: '.$f->bac_start} = '' if( $f->bac_start < $f->seq_start );
      $zmenu->{'91:BAC end: '.$f->bac_end}     = '' if( $f->bac_end   > $f->seq_end   );
    }
   foreach( $f->bacends ) {
      $zmenu->{"18:BACend: $_" } = '';
    }
    $zmenu->{'30:Positioned by:'.$f->positioned_by } = ''        if($f->positioned_by);    
    return $zmenu;
}

1;
