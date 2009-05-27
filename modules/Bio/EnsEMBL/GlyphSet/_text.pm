package Bio::EnsEMBL::GlyphSet::_text;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);

## Get text details...
  my $t = $self->get_text_simple( $self->my_config('text'),$self->my_config('size'));

  $self->push( $self->Text({
## Centre text...
    'width'     => $self->{'container'}->length
    'x'         => 0
    'halign'    => $self->my_config('align')||'center',
    'y'         => 0,
    'height'    => $t->{'height'},
    'font'      => $t->{'font'},
    'ptsize'    => $t->{'fontsize'},
    'colour'    => $self->my_config('col')||'black',
    'text'      => $t->{'original'},
    'absolutey' => 1,
  }));
}

1;
