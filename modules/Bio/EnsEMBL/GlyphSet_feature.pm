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
    my $Config = $self->{'config'};
    my $strand = $self->strand;
    my $strand_flag    = $Config->get($type, 'str');
    return if( $strand_flag eq 'r' && $strand != -1 ||
               $strand_flag eq 'f' && $strand != 1 );

    my $h              = 8;
    my %highlights;
    @highlights{$self->highlights()} = ();

    my @bitmap         = undef;
    my $pix_per_bp     = $Config->transform()->{'scalex'};
    my $bitmap_length  = int($length * $pix_per_bp);
    my $feature_colour = $Config->get(  $type, 'col' );
    my $hi_colour      = $Config->get(  $type, 'hi'  );
    my %id             = ();
    my $small_contig   = 0;
    my $dep            = $Config->get(  $type, 'dep' );

    my $features = $self->features;
    unless(ref($features)eq'ARRAY') {
        warn( ref($self), ' features not array ref ',ref($features) );
        return;
    }

    my ($T,$C1,$C) = (0, 0, 0 );
    if( $dep > 0 ) {
        foreach my $f ( @$features ){
            next if $strand_flag eq 'b' && $strand != $f->strand || $f->start < 1 || $f->end > $length ;
            push @{$id{$f->id()}}, [$f->start,$f->end];
        }
## No features show "empty track line" if option set....
        $self->errorTrack( "No ".$self->my_label." features in this region" ) unless( $Config->get('_settings','opt_empty_tracks')==0 || %id );

## Now go through each feature in turn, drawing them
        my $y_pos;
        foreach my $i (keys %id){
            my $has_origin = undef;
    
            $T+=@{$id{$i}}; ## Diagnostic report....
            my @F = sort { $a->[0] <=> $b->[0] } @{$id{$i}};
            my $bump_start = int($F[0][0] * $pix_per_bp);
               $bump_start = 0 if $bump_start < 0;
            my $bump_end   = int($F[-1][1] * $pix_per_bp);
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
	        'x' => $F[0][0]> 1 ? $F[0][0] : 1,
	        'y' => 0
            });

            my $X = -1000000;
            foreach my $f ( @F ){
                next if int($f->[1] * $pix_per_bp) == int( $X * $pix_per_bp );
                $X = $f->[0];
                $C++;
                $Composite->push(new Sanger::Graphics::Glyph::Rect({
                    'x'          => $X,
                    'y'          => 0, # $y_pos,
                    'width'      => $f->[1]-$X+1,
                    'height'     => $h,
                    'colour'     => $feature_colour,
                    'absolutey'  => 1,
                }));
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
            map { [$_->start, $_->end ] }
            grep { !($strand_flag eq 'b' && $strand != $_->strand || $_->start < 1 || $_->end > $length) } @$features
        ) {
            $T++; $C1++;
            next if( $f->[1] * $pix_per_bp ) == int( $X * $pix_per_bp );
            $X = $f->[0];
            $C++;
            $self->push(new Sanger::Graphics::Glyph::Rect({
                'x'          => $X,
                'y'          => 0, # $y_pos,
                'width'      => $f->[1]-$X+1,
                'height'     => $h,
                'colour'     => $feature_colour,
                'absolutey'  => 1,
            }));
        }
    }
    warn( ref($self), " $C out of a total of ($C1 unbumped) $T glyphs" );
}

1;
