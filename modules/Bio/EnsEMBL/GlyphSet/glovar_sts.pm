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

@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

=head2 my_label

  Arg[1]      : none
  Example     : my $label = $self->my_label;
  Description : returns the label for the track (displayed track name)
  Return type : String - track label
  Exceptions  : none
  Caller      : $self->init_label()

=cut

sub my_label { return "STSs"; }

=head2 features

  Arg[1]      : none 
  Example     : my $f = $self->features;
  Description : this function does the data fetching from the Glovar database
  Return type : listref of Bio::EnsEMBL::ExternalData::Glovar::STS objects
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_ExternalFeatures('GlovarSTS');
}

=head2 colour

  Arg[1]      : a Bio::EnsEMBL::ExternalData::Glovar::STS object
  Example     : my $colour = $self->colour($f);
  Description : sets the colour for displaying STSs. Colour depends on pass
                status
  Return type : List of glyph colour, label colour, glyph style
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub colour {
    my ($self, $f) = @_;
    my $pass = $f->pass_status;
    my $colour = $self->{'colours'}->{$pass} || $self->{'colours'}->{'col'};
    return ($colour, $colour, 'border');
}

=head2 tag

  Arg[1]      : Bio::EnsEMBL::ExternalData::Glovar::STS object
  Example     : my @tags = $self->tag($sts);
  Description : draws filled boxes for the primers at start/end of the STS
  Return type : List of tags
  Exceptions  : none
  Caller      : Bio::EnsEMBL::Glyphset_simple

=cut

sub tag {
    my ($self, $f) = @_;
    my @tags;
    my @colours = $self->colour($f);
    # forward primer
    push @tags, {
      'style'  => 'rect',
      'colour' => $colours[0],
      'start'  => $f->start,
      'end'    => $f->start + $f->sense_length - 1,
    };
    # reverse primer
    push @tags, {
      'style'  => 'rect',
      'colour' => $colours[0],
      'start'  => $f->end - $f->antisense_length + 1,
      'end'    => $f->end,
    };
    return @tags;
}

=head2 href

  Arg[1]      : a Bio::EnsEMBL::ExternalData::Glovar::STS object
  Example     : my $href = $self->href($f);
  Description : returns a href
  Return type : String - href
  Exceptions  : none
  Caller      : $self->_init(), $self->zmenu()

=cut

sub href { 
    my ($self, $f) = @_;
    return $self->ID_URL( 'GLOVAR_STS', $f->dbID );
}

=head2 zmenu

  Arg[1]      : a Bio::EnsEMBL::ExternalData::Glovar::STS object
  Example     : my $zmenu = $self->zmenu($f);
  Description : creates the zmenu (context menu) for the glyphset. Returns a
                hashref describing the zmenu entries and properties
  Return type : hashref
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub zmenu {
    my ($self, $f) = @_;
    return {
        'caption' => $f->display_id,
        '01:ID: '.$f->dbID => '',
        '02:Test status: '.$f->pass_status => '',
        '03:Assay type: '.$f->assay_type => '',
        '04:Source: Glovar' => '',
        "05:STS Report" => $self->href($f),
    };
}
1;
