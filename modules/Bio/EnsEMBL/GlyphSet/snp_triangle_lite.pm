package Bio::EnsEMBL::GlyphSet::snp_triangle_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::snp_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::snp_lite);

sub tag {
    my ($self, $f) = @_; 
    return ( {
        'style'  => 'triangle',
        'colour' => $self->colour($f)
    } );
}

sub colour {
    my ($self, $f) = @_;
    my $T = substr($f->{'type'},3);
    unless($self->{'config'}->{'snp_types'}{$T}) {
        my %labels = (
            '_coding' => 'Coding SNPs',
            '_utr'    => 'UTR SNPs',
            '_intron' => 'Intronic SNPs',
            '_local'  => 'Flanking SNPs',
            '_'       => 'other SNPs'
        );
        push @{ $self->{'config'}->{'snp_legend_features'}->{'snps'}->{'legend'} }, $labels{"_$T"} => $self->{'colours'}{"_$T"};
        $self->{'config'}->{'snp_types'}{$T}=1;
    }
    return $self->{'colours'}{"_$T"}, $self->{'colours'}{"_$T"}, 'line';
}
1;
