package Bio::EnsEMBL::GlyphSet_feature2;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Bump;

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
        'caption' => "Unknown",
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

    my $WIDTH          = 1e5;
    my $container      = $self->{'container'};
    my $Config         = $self->{'config'};
    my $strand         = $self->strand();
    my $strand_flag    = $Config->get($type, 'str');
    return if( $strand_flag eq 'r' && $strand != -1 ||
               $strand_flag eq 'f' && $strand != 1 );

    my $h              = 8;
    my %highlights;
    @highlights{$self->highlights()} = ();
    my $length         = $container->length;
    my @bitmap         = undef;
    my $pix_per_bp     = $Config->transform()->{'scalex'};
    my $bitmap_length  = int($length * $pix_per_bp);
    my $feature_colour = $Config->get($type, 'col');
    my $hi_colour      = $Config->get($type, 'hi');
    my %id             = ();
    my $small_contig   = 0;
    my $dep            = $Config->get($type, 'dep');
    my $chr_name       = $self->{'container'}->chr_name;
    my $offset         = $self->{'container'}->chr_start - 1;
    my ($T,$C1,$C) = (0, 0, 0 );


    if( $dep > 0 ) {
        foreach my $f ( @{$self->features()} ){
            next if $strand_flag eq 'b' && $strand != $f->hstrand ;
            next if $f->start > $f->end || $f->end < 1 || $f->start > $length;
            $id{$f->hseqname()} = [] unless $id{$f->hseqname()};
            push @{$id{$f->hseqname()}}, $f;
        }

## No features show "empty track line" if option set....
        $self->errorTrack( "No ".$self->my_label." in this region" )
            unless( $Config->get('_settings','opt_empty_tracks')==0 || %id );

## Now go through each feature in turn, drawing them
        my @glyphs;
        foreach my $i (keys %id){
            my $has_origin = undef;
    
            my $start;
            my $end;
    
            my $Composite = new Sanger::Graphics::Glyph::Composite({});
            
            foreach my $f (@{$id{$i}}){
                my $START = $f->start();
                my $END   = $f->end();
                ($START,$END) = ($END, $START) if $END<$START;
                $START = 1 if $START < 1;
                $END   = $length if $END > $length;
                unless (defined $has_origin){
                    $Composite->x($f->start());
                    $Composite->y(0);
        	        $start = $f->hstart();
        	        $end   = $f->hend();
                    $has_origin = 1;
                } else {
    	            $start = $f->hstart() if $f->hstart < $start;
    	            $end   = $f->hend()   if $f->hend   > $end;
                }
       #     print STDERR "F: ",$f->id," - ",$f->start()," - ",$f->end(),"\n";
                my $glyph = new Sanger::Graphics::Glyph::Rect({
                    'x'          => $START,
                    'y'          => 0,
                    'width'      => $END-$START+1,
                    'height'     => $h,
                    'colour'     => $feature_colour,
                    'absolutey'  => 1,
                    '_feature'   => $f, 
                });
                $Composite->push($glyph);
            }
        
            my $ZZ;
            if($end-$start<$WIDTH) {
        	    my $X =int(( $start + $end - $WIDTH) /2);
        	    my $Y = $X + $WIDTH ;
                $ZZ = "chr=$i&vc_start=$X&vc_end=$Y";
        	} else {
                $ZZ = "chr=$i&vc_start=$start&vc_end=$end";
            }
        	$Composite->zmenu( $self->zmenu( "Chr$i $start-$end", $ZZ ) );
        	$Composite->href(  $self->href( $i, $ZZ ) );
    
            my $bump_start = int($Composite->x() * $pix_per_bp);
            $bump_start--;
            $bump_start    = 0 if $bump_start < 0;
                
            my $bump_end = $bump_start + ($Composite->width() * $pix_per_bp);
            $bump_end    = $bitmap_length if $bump_end > $bitmap_length;
            my $row = & Sanger::Graphics::Bump::bump_row(
                $bump_start,    $bump_end,    $bitmap_length,    \@bitmap
            );
    
            next if $row > $dep;
            $Composite->y( $Composite->y() - 1.5 * $row * $h * $strand );
            
                # if we are bumped && on a large contig then draw frames around features....
            $Composite->bordercolour($feature_colour) unless ($small_contig);
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
    } else { ## Unbumped....!
        my $X = -1e8;
        foreach (
            sort { $a->[0] <=> $b->[0] }
            map { [$_->start, $_ ] }
            grep { !($strand_flag eq 'b' && $strand != $_->hstrand || $_->end < 1 || $_->start > $length) } @{$self->features()}
        ) {
            my $f       = $_->[1];
            my $START   = $_->[0];
            my $END     = $f->end;
            ($START,$END) = ($END, $START) if $END<$START; # Flip start end YUK!
            $START      = 1 if $START < 1;
            $END        = $length if $END > $length;
            $T++; $C1++;
            next if( $END * $pix_per_bp ) == int( $X * $pix_per_bp );
            $X = $START;
            $C++;
            my @X = ( [ $chr_name, $offset+ int(($_->[0]+$f->end)/2) ], [ $f->hseqname, int(($f->hstart + $f->hend)/2) ] );
            my $glyph = new Sanger::Graphics::Glyph::Rect({
                'x'          => $START,
                'y'          => 0,
                'width'      => $END-$START+1,
                'height'     => $h,
                'colour'     => $feature_colour,
                'absolutey'  => 1,
                '_feature'   => $f, 
                'href'       => $self->unbumped_href( @X ),
                'zmenu'      => $self->unbumped_zmenu( @X )
            });
            $self->push($glyph);
        }
    }
    warn( ref($self), " $C out of a total of ($C1 unbumped) $T glyphs" );
}

1;
