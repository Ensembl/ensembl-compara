=head1 NAME

Bio::EnsEMBL::GlyphSet::glovar_haplotype -
Glyphset to draw haplotype blocks

=head1 DESCRIPTION

This glyphset fetches haplotype data from Glovar and draws haplotype blocks.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::GlyphSet::glovar_haplotype;
use strict;
use vars qw(@ISA);
use Digest::MD5 qw(md5_hex);
use Bio::EnsEMBL::GlyphSet_feature;

@ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

=head2 my_label

  Arg[1]      : none
  Example     : my $label = $self->my_label;
  Description : returns the label for the track (displayed track name)
  Return type : String - track label
  Exceptions  : none
  Caller      : $self->init_label()

=cut

sub my_label { return "Glovar Haplotype"; }

=head2 features

  Arg[1]      : none 
  Example     : my $f = $self->features;
  Description : this function does the data fetching from the Glovar database
  Return type : listref of Bio::EnsEMBL::DnaDnaAlignFeature objects
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_ExternalLiteFeatures('GlovarHaplotype');
}

=head2 colour

  Arg[1]      : feature ID
  Arg[2]      : a Bio::EnsEMBL::DnaDnaAlignFeature object
  Example     : my $colour = $self->colour($id, $f);
  Description : sets the colour for displaying haplotypes. The colour is
                dynamically generated from the population name
  Return type : String - colour name
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub colour {
    my ($self, $id, $f) = @_;
    ## create a reproducable random colour from the population
    ## (possible improvement: exclude very light and very dark colours)
    my $hex = substr(md5_hex($f->{'_population'}), 0, 6);
    return $self->{'config'}->colourmap->add_hex($hex);
}

=head2 href

  Arg[1]      : feature ID
  Example     : my $href = $self->href($id);
  Description : returns a href
  Return type : String - href
  Exceptions  : none
  Caller      : $self->_init(), $self->zmenu()

=cut

sub href { 
    my ($self, $id) = @_;
    return $self->ID_URL( 'GLOVAR_HAPLOTYPE', $id );
}

=head2 zmenu

  Arg[1]      : feature ID
  Arg[2]      : a listref of Bio::EnsEMBL::DnaDnaAlignFeature objects
  Example     : my $zmenu = $self->zmenu($id, $feature_array);
  Description : creates the zmenu (context menu) for the glyphset. Returns a
                hashref describing the zmenu entries and properties
  Return type : hashref
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub zmenu {
    my ($self, $id, $f_arr) = @_;
    ## get first object of the Haplotype group
    my $f = $f_arr->[0][2];
    return {
        'caption' => $f->hseqname,
        '01:ID: '.$id => '',
        '02:Population: '.$f->{'_population'} => '',
        '03:Length: '.$f->{'_block_length'} => '',
        '04:No. SNPs: '.$f->{'_num_snps'} => '',
        "06:Haplotype Report" => $self->href( $id ),
    };
}
1;
