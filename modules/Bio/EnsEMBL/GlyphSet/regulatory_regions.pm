package Bio::EnsEMBL::GlyphSet::regulatory_regions;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }
sub my_label { return "Regulatory regions"; }

sub my_description { return "Regulatory regions"; }

# This for 
sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    my $slice = $self->{'container'};
    return $slice->adaptor->db->get_RegulatoryFeatureAdaptor->fetch_all_by_Slice_constraint( $slice );  # $logic name is second param
}

sub href {
    my ($self, $f ) = @_;
    return undef;
}

sub zmenu {
    my ($self, $f ) = @_;
    my $name = $f->name();
    $name =~ s/(.*):.*/$1/;
    my ($start,$end) = $self->slice2sr( $f->start, $f->end );
    my $factor = $f->factor->name;
    my $regulated_transcripts = $f->regulated_transcripts;
    warn $regulated_transcripts->[0];

    return {
        'caption'                         => 'regulatory_regions',
        "02:Gene:$name"                        => "geneview?gene=$name",
        "03:bp: $start-$end"              => '',
        "01:Factor: $factor"              => ''
    };
}
1;
