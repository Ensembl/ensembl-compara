package Bio::EnsEMBL::GlyphSet::SE_generic_match;
use strict;
use Bio::EnsEMBL::GlyphSet::TSE_generic_match;
@Bio::EnsEMBL::GlyphSet::SE_generic_match::ISA = qw(Bio::EnsEMBL::GlyphSet::TSE_generic_match);
use Data::Dumper;
$Data::Dumper::Maxdepth = 3;

sub init_label {
    my ($self) = @_;
    $self->init_label_text();
}

sub _init {
    my ($self) = @_;
    my $all_matches = $self->{'config'}->{'transcript'}{'evidence'};
    $self->draw_glyphs($all_matches);
}

1;
