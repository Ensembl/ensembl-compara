package Bio::EnsEMBL::GlyphSet::Vannotation_status;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my $self = shift;

    ## get NoAnnotation features from db
    my $chr = $self->{'container'}->{'chr'};
    my $slice_adapt   = $self->{'container'}->{'sa'};  
    my $chr_slice = $slice_adapt->fetch_by_region('chromosome', $chr);
    my $features = $chr_slice->get_all_MiscFeatures('NoAnnotation');

    ## get configuration
    my $colour = $self->{'config'}->get($self->check, 'colour');
    my $tag_pos = $self->{'config'}->get($self->check, 'tag_pos');

    ## draw the glyphs
    foreach my $f (@$features) {
        my $glyph = new Sanger::Graphics::Glyph::Rect({
            'x'      => $f->start,
            'y'      => 0,
            'width'  => $f->end-$f->start,
            'height' => 1,
            'colour' => $colour,
        });
        $self->push($glyph);

        ## tagging
        $self->join_tag($glyph, $f->end."-".$f->start, $tag_pos, $tag_pos, $colour, 'fill', -10);
        $self->join_tag($glyph, $f->end."-".$f->start, 1-$tag_pos, $tag_pos, $colour, 'fill', -10);
    }
}

1;
