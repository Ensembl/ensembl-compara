package Bio::EnsEMBL::GlyphSet::snp_triangle_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::snp_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::snp_lite);

sub tag {
    my ($self, $f) = @_; 
    my ($col,$labcol) =  $self->colour($f);
    warn( "snp - $col - $labcol" );
    if($f->snpclass eq 'snp' ) {
	return( { 'style' => 'box', 'letter' => $f->{'_ambiguity_code'}, 'colour' => $col, 'label_colour' => $labcol } );
    }
    if($f->{'_range_type'} eq 'between' ) {
	return( { 'style' => 'left-snp', 'colour' => $col } );
    }
    if($f->snpclass eq 'in-del' ) {
	return( { 'style' => 'delta', 'colour' => $col } );
    }
    return ( { 'style'  => 'box', 'colour' => $col, 'letter' => ' ' } );
}

sub colour {
    my ($self, $f) = @_;
    my $T = substr($f->type,3,6);
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
    return( $self->{'colours'}{"_$T"}, $self->{'colours'}{"label_$T"}, 'invisible' );
}

1;
