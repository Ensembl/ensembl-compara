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


sub colour {
    my ($self, $f) = @_;
    my $type = $f->positioned_by();
    return $self->{'colours'}{"col_$type"}, $self->{'colours'}{"lab_$type"}, '';
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
    return "/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=".$f->name
}

sub tag {
    my ($self, $f) = @_; 
    my @result = (); 
    if( $f->fp_size && $f->fp_size > 0 ) {
        my $start = int( ($f->start + $f->end - $f->fp_size)/2 );
        my $end   = $start + $f->fp_size - 1 ;
        push @result, {
            'style' => 'underline',
            'colour' => $self->{'colours'}{"seq_len"},
            'start'  => $start,
            'end'    => $end
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
    foreach( $f->bacends ) {
      $zmenu->{"18:BACend: $_" } = '';
    }
    $zmenu->{'30:Positioned by:'.$f->positioned_by } = ''        if($f->positioned_by);    
    return $zmenu;
}

1;
