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
    my @features = $self->{'container'}->get_all_MapFrags( 'cloneset' );
    return grep { abs( $_->end - $_->start ) < 3e6 } @features;
}

## If bac map clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality...


sub colour {
    my ($self, $f) = @_;
    $self->{'_colour_flag'} = $self->{'_colour_flag'}==1 ? 2 : 1;
    return 
        $self->{'colours'}{"col$self->{'_colour_flag'}"},
        $self->{'colours'}{"lab$self->{'_colour_flag'}"},
        $f->length > $self->{'config'}->get( "tilepath2", 'outline_threshold' ) ? 'border' : '' ;
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
    $zmenu->{'13:Organisation: '.$f->organisation} = '' if($f->organisation);
    $zmenu->{'14:State: '.substr($f->state,3)        } = ''              if($f->state);
    $zmenu->{'15:Seq length: '.$f->seq_len } = ''        if($f->seq_len);    
    $zmenu->{'16:FP length:  '.$f->fp_size } = ''        if($f->fp_size);    
    $zmenu->{'17:super_ctg:  '.$f->superctg} = ''        if($f->superctg);    
    $zmenu->{'18:BAC flags:  '.$f->bacinfo } = ''        if($f->BACend_flag);    
    $zmenu->{'18:FISH:  '.$f->FISHmap } = ''        if($f->FISHmap);    
    $zmenu->{'30:'.$f->note } = ''        if($f->note);    
    return $zmenu;
}

1;
