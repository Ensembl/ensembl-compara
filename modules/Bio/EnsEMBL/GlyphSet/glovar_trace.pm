=head1 NAME

Bio::EnsEMBL::GlyphSet::glovar_trace -
Glyphset to diplay traces from Glovar

=head1 DESCRIPTION

Displays traces stored in a glovar database

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::GlyphSet::glovar_trace;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

=head2 my_label

  Arg[1]      : none
  Example     : my $label = $self->my_label;
  Description : returns the label for the track (displayed track name)
  Return type : String - track label
  Exceptions  : none
  Caller      : $self->init_label()

=cut

sub my_label { return "Glovar Traces"; }

=head2 features

  Arg[1]      : none 
  Example     : my $f = $self->features;
  Description : this function does the data fetching from the Glovar database
  Return type : listref of Bio::EnsEMBL::MapFrag objects
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_ExternalLiteFeatures('GlovarTrace');
}

=head2 href

  Arg[1]      : a Bio::EnsEMBL::MapFrag object
  Example     : my $href = $self->href($f);
  Description : returns a href
  Return type : String - href
  Exceptions  : none
  Caller      : $self->_init(), $self->zmenu()

=cut

sub href { 
    my ($self, $f) = @_;
    return $self->ID_URL( 'TRACE', $f->id );
}

=head2 zmenu

  Arg[1]      : a Bio::EnsEMBL::MapFrag object
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
        'caption' => $f->name,
        '01:Chr start: '.$f->seq_start => '',
        '02:Chr end: '.$f->seq_end => '',
        '03:Read start: '.$f->read_start => '',
        '04:Read end: '.$f->read_end => '',
        '05:Trace Details' => $self->ID_URL( 'TRACE', $f->id ),
    };
}
1;
