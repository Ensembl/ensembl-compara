=head1 NAME

Bio::EnsEMBL::GlyphSet::snp_triangle_glovar -
Glyphset to display Glovar SNP neighbourhood in snpview

=head1 DESCRIPTION

Displays SNP neighbourhood for Glovar SNP in snpview

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::GlyphSet::snp_triangle_glovar;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::glovar_snp;
@ISA = qw(Bio::EnsEMBL::GlyphSet::glovar_snp);

=head2 tag

  Arg[1]      : a Bio::EnsEMBL::SNP object
  Example     : my $tag = $self->tag($f);
  Description : retrieves the SNP tag (ambiguity code) in the right colour
  Return type : hashref
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub tag {
    my ($self, $f) = @_; 
    my ($col,$labcol) =  $self->colour($f);
    #warn( "snp - $col - $labcol" );
    if ($f->snpclass eq 'SNP - substitution') {
	return( { 'style' => 'box', 'letter' => $f->ambiguity_code, 'colour' => $col, 'label_colour' => $labcol } );
    }
    if ($f->snpclass =~ /Complex/) {
	return( { 'style' => 'left-snp', 'colour' => $col } );
    }
    if ($f->snpclass eq 'SNP - indel' ) {
        if ($f->start == $f->end) {
	    return( { 'style' => 'delta', 'colour' => $col } );
        } else {
            return( { 'style' => 'left-snp', 'colour' => $col } );
        }
    }
    return ( { 'style'  => 'box', 'colour' => $col, 'letter' => ' ' } );
}

=head2 colour

  Arg[1]      : a Bio::EnsEMBL::SNP object
  Example     : my $colour = $self->colour($f);
  Description : sets the colour for displaying SNPs. They are coloured
                according to their position on genes
  Return type : list of colour settings
  Exceptions  : none
  Caller      : $self->_init()

=cut

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
