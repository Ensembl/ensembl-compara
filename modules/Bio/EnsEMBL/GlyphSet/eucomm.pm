=head1 NAME

Bio::EnsEMBL::GlyphSet::eucomm.pm
GlyphSet to draw EUCOMM simple features

=head1 DESCRIPTION

Displays EUCOMM critical exons stored as simple features.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHORS

Steve Trevanion <st3@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::GlyphSet::eucomm;
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

sub my_label {
    my $self = shift;
    return $self->my_config('label');
}

=head2 features

  Arg[1]      : none 
  Example     : my $f = $self->features;
  Description : this function does the data fetching from the core database
  Return type : listref of EUCOMM simple features
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimpleFeatures($self->my_config('logic_name'), 0);
}


=head2 zmenu

  Arg[1]      : feature ID
  Arg[2]      : a listref of EUCOMM simple features
  Example     : my $zmenu = $self->zmenu($id, $feature_array);
  Description : creates the zmenu (context menu) for the glyphset. Returns a
                hashref describing the zmenu entries and properties
  Return type : hashref
  Exceptions  : none
  Caller      : 

=cut

sub zmenu {
  my ($self, $f ) = @_;
  my $start = $self->{'container'}->start() + $f->start() - 1;
  my $end   = $self->{'container'}->start() + $f->end() - 1;
  my $score = $f->score();

  return {
        'caption' => $self->my_config('label'),
        "01:bp: $start-$end" => '',
		"02:score: $score" => '',
    };
}
1;
