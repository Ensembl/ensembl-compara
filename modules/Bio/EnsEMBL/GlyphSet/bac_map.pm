package Bio::EnsEMBL::GlyphSet::bac_map;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "BAC map"; }

## Retrieve all BAC map clones - these are the clones in the
## subset "bac_map" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_bac_map")

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();
    my $max_full_length  = $self->{'config'}->get( "bac_map", 'full_threshold' ) || 200000000;
    return 
      map { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
          map { [$_->seq_start-$_->state*1e9 * $_->BACend_flag/4, $_] }
            $self->{'container'}->get_all_MapFrags(
              $container_length > $max_full_length ? 'acc_bac_map' : 'bac_map'
            );
}

## If bac map clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality...


sub colour {
    my ($self, $f) = @_;
    my $state = substr($f->state,3);
    return $self->{'colours'}{"col_$state"},
           $self->{'colours'}{"lab_$state"},
           $f->length > $self->{'config'}->get( "bac_map", 'outline_threshold' ) ? 'border' : ''
           ;
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
    my $bef = $f->BACend_flag;
    push @result, {
        'style'  => 'right-end',
        'colour' => $self->{'colours'}{"bacend"}
    } if ( $bef == 2 || $bef == 3 );
    push @result, { 
        'style'=>'left-end',  
        'colour' => $self->{'colours'}{"bacend"}
    } if ( $bef == 1 || $bef == 3 );
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
    foreach($f->embl_accs) {
        $zmenu->{"12:EMBL: $_" } = '';
    }
    $zmenu->{'13:Organisation: '.$f->organisation} = '' if($f->organisation);
    $zmenu->{'14:State: '.substr($f->state,3)        } = ''              if($f->state);
    $zmenu->{'15:Seq length: '.$f->seq_len } = ''        if($f->seq_len);    
    $zmenu->{'16:FP length:  '.$f->fp_size } = ''        if($f->fp_size);    
    $zmenu->{'17:super_ctg:  '.$f->superctg} = ''        if($f->superctg);    
    $zmenu->{'18:BAC flags:  '.$f->bacinfo } = ''        if($f->BACend_flag);    
    $zmenu->{'19:FISH:  '.$f->FISHmap } = ''        if($f->FISHmap);    
    return $zmenu;
}

1;
