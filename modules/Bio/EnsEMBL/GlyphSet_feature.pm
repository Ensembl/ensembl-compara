package Bio::EnsEMBL::GlyphSet_feature;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => $self->my_label(),
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
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

sub _init {
    my ($self) = @_;

    my ($type)         = reverse split '::', ref($self) ;
    my $VirtualContig  = $self->{'container'};
    my $Config         = $self->{'config'};
    my $strand         = $self->strand();
    my $h              = 8;
    my %highlights;
    @highlights{$self->highlights()} = ();
    my @bitmap         = undef;
    my $pix_per_bp     = $Config->transform()->{'scalex'};
    my $bitmap_length  = int($VirtualContig->length * $pix_per_bp);
    my $feature_colour = $Config->get($type, 'col');
    my $hi_colour      = $Config->get($type, 'hi');
    my %id             = ();
    my $small_contig   = 0;
    my $dep            = $Config->get($type, 'dep');

    my @glyphs;

    foreach my $f ($self->features){
        $id{$f->id()} = [] unless $id{$f->id()};
        push(@{$id{$f->id()}}, $f );
    }

    my @glyphs;

    foreach my $i (keys %id){
        @{$id{$i}} =  sort {$a->start() <=> $b->start() } @{$id{$i}};
        my $j = 1;
    
        my $has_origin = undef;
    
        my $Composite = new Bio::EnsEMBL::Glyph::Composite({
            'zmenu'     => $self->zmenu( $i )
        });
        foreach my $f (@{$id{$i}}){
            unless (defined $has_origin){
                $Composite->x($f->start());
                $Composite->y(0);
                $has_origin = 1;
            }
            my $glyph = new Bio::EnsEMBL::Glyph::Rect({
                'x'          => $f->start(),
                'y'          => 0,
                'width'      => $f->length(),
                'height'     => $h,
                'colour'     => $feature_colour,
                'absolutey' => 1,
                '_feature'     => $f, 
            });
            $Composite->push($glyph);
            $j++;
        }
    
        if ($dep > 0){ # we bump
            my $bump_start = int($Composite->x() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
            
            my $bump_end = $bump_start + ($Composite->width() * $pix_per_bp);
            $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
            my $row = &Bump::bump_row(
                $bump_start,
                $bump_end,
                $bitmap_length,
                \@bitmap
            );

            next if ($row > $dep);
            $Composite->y($Composite->y() + (1.5 * $row * $h * -$strand));
        
            # if we are bumped && on a large contig then draw frames around features....
            $Composite->bordercolour($feature_colour) unless ($small_contig);
        }
        push @glyphs ,$Composite;
        if(exists $highlights{$i}) {
            my $glyph = new Bio::EnsEMBL::Glyph::Rect({
                'x'        => $Composite->x() - 1/$pix_per_bp,
                'y'        => $Composite->y()-1,
                'width'        => $Composite->width() + 2/$pix_per_bp,
                'height'    => $h + 2,
                'colour'    => $hi_colour,
                'absolutey' => 1,
            });
            $self->push($glyph);
        }
    }

    foreach ( @glyphs ) {
        $self->push($_);
    }
}

1;
