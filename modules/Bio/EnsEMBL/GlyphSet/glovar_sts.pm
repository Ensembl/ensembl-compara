=head1 NAME

Bio::EnsEMBL::GlyphSet::glovar_sts -
Glyphset to draw STSs from Glovar

=head1 DESCRIPTION

Displays STSs stored in a Glovar database

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::GlyphSet::glovar_sts;
use strict;
use vars qw(@ISA);
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

sub my_label { return "Glovar STS"; }

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
    return $self->{'container'}->get_all_ExternalLiteFeatures('GlovarSTS');
}

=head2 colour

  Arg[1]      : feature ID
  Arg[2]      : a Bio::EnsEMBL::DnaDnaAlignFeature object
  Example     : my $colour = $self->colour($id, $f);
  Description : sets the colour for displaying STSs. Colour depends on pass
                status
  Return type : String - colour name
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub colour {
    my ($self, $id, $f) = @_;
    return $self->{'colours'}->{$f->{'_pass'}}
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
    return $self->ID_URL( 'GLOVAR_STS', $id );
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
    ## get first object of the STS pair
    my $f = $f_arr->[0][2];
    return {
        'caption' => $f->hseqname,
        '01:ID: '.$id => '',
        '02:Test status: '.$f->{'_pass'} => '',
        "03:STS Report" => $self->href( $id ),
    };
}
1;
