=head1 NAME

Bio::EnsEMBL::GlyphSet::polyA_site.pm
GlyphSet to draw polyA sites

=head1 DESCRIPTION

Displays polyA sites stored in simple_feature

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Steve Trevanion <st3@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::GlyphSet::polyA_site;
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

sub my_label { return "PolyA sites"; }


=head2 features

  Arg[1]      : none 
  Example     : my $f = $self->features;
  Description : this function does the data fetching from the core database
  Return type : listref of Bio::EnsEMBL::DnaDnaAlignFeature objects
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_SimpleFeatures('polyA_site', 0);
}


=head2 zmenu

  Arg[1]      : feature ID
  Arg[2]      : a listref of Bio::EnsEMBL::DnaDnaAlignFeature objects
  Example     : my $zmenu = $self->zmenu($id, $feature_array);
  Description : creates the zmenu (context menu) for the glyphset. Returns a
                hashref describing the zmenu entries and properties
  Return type : hashref
  Exceptions  : none
  Caller      : 

=cut

sub zmenu {
  my ($self, $f ) = @_;
  
  my $score = $f->score();
  my $start = $self->{'container'}->start() + $f->start() - 1;
  my $end   = $self->{'container'}->start() + $f->end() - 1;

  return {
        'caption' => 'polyA site',
        "01:Score: $score" => '',
        "02:bp: $start-$end" => ''
    };
}
1;
