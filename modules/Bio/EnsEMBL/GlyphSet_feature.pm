package Bio::EnsEMBL::GlyphSet_feature;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use  Sanger::Graphics::Bump;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $HELP_LINK = $self->check();
    my $label = new Sanger::Graphics::Glyph::Text({
        'text'      => $self->my_label(),
        'font'      => 'Small',
        'absolutey' => 1,
        'href'      => qq[javascript:X=window.open(\'/$ENV{'ENSEMBL_SPECIES'}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#$HELP_LINK\',\'helpview\',\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\');X.focus();void(0)],

        'zmenu'     => {
            'caption'                     => 'HELP',
            "01:Track information..."     =>
qq[javascript:X=window.open(\\\'/$ENV{'ENSEMBL_SPECIES'}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#$HELP_LINK\\\',\\\'helpview\\\',\\\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\\\');X.focus();void(0)]
        }
    });
    $self->label($label);
    $self->bumped( $self->{'config'}->get($HELP_LINK, 'dep')==0 ? 'no' : 'yes' );
}

sub my_label {
    my ($self) = @_;
    return 'Missing label';
}

sub features {
    my ($self) = @_;
    return ();
} 

sub zmenu {
    my ($self, $id ) = @_;

    return {
        'caption' => $self->check(),
        "$id"     => "You must write your own zmenu call"
    };
}

sub href {
    my ($self, $id ) = @_;

    return undef;
}

sub _init {
    my ($self) = @_;

    my $type = $self->check();
    return unless defined $type;

    my $length = $self->{'container'}->length();
    my $strand = $self->strand;
    my $Config = $self->{'config'};
    my $strand_flag    = $Config->get($type, 'str');
    return if( $strand_flag eq 'r' && $strand != -1 ||
               $strand_flag eq 'f' && $strand != 1 );
    my $pix_per_bp     = $Config->transform()->{'scalex'};
    my $DRAW_CIGAR     = $pix_per_bp > 0.2 ;

    my $h              = 8;
    my %highlights;
    @highlights{$self->highlights()} = ();

    my @bitmap         = undef;
    my $bitmap_length  = int($length * $pix_per_bp);
    my $feature_colour = $Config->get(  $type, 'col' );
    my $hi_colour      = $Config->get(  $type, 'hi'  );
    my %id             = ();
    my $small_contig   = 0;
    my $dep            = $Config->get(  $type, 'dep' );

    my $features = $self->features;
    unless(ref($features)eq'ARRAY') {
        return;
    }

    my ($T,$C1,$C) = (0, 0, 0 );
    if( $dep > 0 ) {
        foreach my $f ( @$features ){
            next if $strand_flag eq 'b' && $strand != $f->strand || $f->end < 1 || $f->start > $length ;
            push @{$id{$f->id()}}, [$f->start,$f->end,$f];
        }
## No features show "empty track line" if option set....
        $self->errorTrack( "No ".$self->my_label." features in this region" ) unless( $Config->get('_settings','opt_empty_tracks')==0 || %id );

## Now go through each feature in turn, drawing them
        my $y_pos;
        foreach my $i (sort(keys %id)){

            my $has_origin = undef;
    
            $T+=@{$id{$i}}; ## Diagnostic report....
            my @F = sort { $a->[0] <=> $b->[0] } @{$id{$i}};
            my $START = $F[0][0] < 1 ? 1 : $F[0][0];
            my $END   = $F[-1][1] > $length ? $length : $F[-1][1];
            my $bump_start = int($START * $pix_per_bp);
               $bump_start--; 
               $bump_start = 0 if $bump_start < 0;
            my $bump_end   = int($END * $pix_per_bp);
               $bump_end   = $bitmap_length if $bump_end > $bitmap_length;
            my $row = & Sanger::Graphics::Bump::bump_row(
                $bump_start,    $bump_end,    $bitmap_length,    \@bitmap
            );
            next if $row > $dep;
            $y_pos = - 1.5 * $row * $h * $strand;
        
            $C1 += @{$id{$i}}; ## Diagnostic report....

            my $Composite = new Sanger::Graphics::Glyph::Composite({
                'zmenu'    => $self->zmenu( $i ),
                'href'     => $self->href( $i ),
	            'x' => $F[0][0]> 1 ? $F[0][0]-1 : 0,
                    'width' => 0,
	            'y' => 0
            });

            my $X = -1000000;
            foreach my $f ( @F ){
                next if int($f->[1] * $pix_per_bp) == int( $X * $pix_per_bp );
                $C++;
                if($DRAW_CIGAR) {
                  $self->draw_cigar_feature($Composite, $f->[2], $h, $feature_colour, 'black', $pix_per_bp );
                } else {
                  my $START = $f->[0] < 1 ? 1 : $f->[0];
                  my $END   = $f->[1] > $length ? $length : $f->[1];
                  $X = $START;
                  $Composite->push(new Sanger::Graphics::Glyph::Rect({
                    'x'          => $X-1,
                    'y'          => 0, # $y_pos,
                    'width'      => $END-$X+1,
                    'height'     => $h,
                    'colour'     => $feature_colour,
                    'absolutey'  => 1,
                  }));
                }
            }
            $Composite->y( $Composite->y + $y_pos );
            $Composite->bordercolour($feature_colour);
            $self->push( $Composite );
            if(exists $highlights{$i}) {
                my $glyph = new Sanger::Graphics::Glyph::Rect({
                    'x'         => $Composite->x() - 1/$pix_per_bp,
                    'y'         => $Composite->y() - 1,
                    'width'     => $Composite->width() + 2/$pix_per_bp,
                    'height'    => $h + 2,
                    'colour'    => $hi_colour,
                    'absolutey' => 1,
                });
                $self->unshift( $glyph );
            }
        }
    } else { ## Treat as very simple simple features...
        my $X = -1e8;
        foreach my $f (
            sort { $a->[0] <=> $b->[0] }
            map { [$_->start, $_->end,$_ ] }
            grep { !($strand_flag eq 'b' && $strand != $_->strand || $_->start > $length || $_->end < 1) } @$features
        ) {
            my $START   = $f->[0];
            my $END     = $f->[1];
            ($START,$END) = ($END, $START) if $END<$START; # Flip start end YUK!
            $START      = 1 if $START < 1;
            $END        = $length if $END > $length;
            $T++; $C1++;
            next if( $END * $pix_per_bp ) == int( $X * $pix_per_bp );
            $X = $START;
            $C++;
            if($DRAW_CIGAR) {
               $self->draw_cigar_feature($self, $f->[2], $h, $feature_colour, 'black', $pix_per_bp );
            } else {
	      $self->push(new Sanger::Graphics::Glyph::Rect({
                'x'          => $X-1,
                'y'          => 0, # $y_pos,
                'width'      => $END-$X+1,
                'height'     => $h,
                'colour'     => $feature_colour,
                'absolutey'  => 1,
              }));
            }
        }
    }
    # warn( ref($self), " $C out of a total of ($C1 unbumped) $T glyphs" );
}

1;
