package Bio::EnsEMBL::GlyphSet::est;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_feature;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { return "ESTs"; }

sub features {
    my ($self) = @_;
    return map { ($_->strand() == $self->strand) && ($_->source_tag() eq 'est') ? $_ : () } $self->{'container'}->get_all_ExternalFeatures($self->glob_bp)

}
sub zmenu {
    my ($self, $id ) = @_;
    my $estid = $id;
    $estid =~s/(.*?)\.\d+/$1/;
    return { 'caption' => "EST $id",
	     "$id"     => "http://www.sanger.ac.uk/srs6bin/cgi-bin/wgetz?-e+[DBEST-ALLTEXT:$estid]" }
}
1;
