package Bio::EnsEMBL::GlyphSet::tilepath;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::bac_map;
@ISA = qw(Bio::EnsEMBL::GlyphSet::bac_map);

sub my_label { return "Tilepath"; }

## Retrieve all tile path clones - these are the clones in the
## subset "tilepath".

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_MiscFeatures( 'tilepath' );
}

## If tile path clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality...
sub tag {
  my ($self, $f) = @_;
  my @result = ();

  if( $f->get_scalar_attribute('FISHmap') ) {
    push @result, {
      'style' => 'left-triangle',
      'colour' => $self->{'colours'}{"fish_tag"},
    }
  }
  return @result;
}

sub colour {
    my ($self, $f ) = @_;
    $self->{'_colour_flag'} = $self->{'_colour_flag'}==1 ? 2 : 1;
    return 
        $self->{'colours'}{"col$self->{'_colour_flag'}"},
        $self->{'colours'}{"lab$self->{'_colour_flag'}"},
        $f->length > $self->{'config'}->get( "tilepath2", 'outline_threshold' ) ? 'border' : '' ;
}

1;
