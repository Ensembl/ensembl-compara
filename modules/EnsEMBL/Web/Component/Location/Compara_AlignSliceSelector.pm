package EnsEMBL::Web::Component::Location::Compara_AlignSliceSelector;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self   = shift;
  my $url = $object->_url({}, 1 );
  my $extra_inputs;
  foreach(sort keys %{$url->[1]||{}}) {
    $extra_inputs .= sprintf '
      <input type="hidden" name="%s" value="%s" />', escapeHTML($_),escapeHTML($url->[1]{$_});
  }

  $options = {};
  my $align = $self->object->param('align');
## Get the compara database hash!

  my $h = $self->object->species_defs->multi_hash->{'DATABASE_COMPARA'};

## Get the species in the alignment and turn on the approriate Synteny tracks!
  if( $h && exists $h->{'ALIGNMENTS'} && exists $h->{'ALIGNMENTS'}{$align} ) {
    foreach( keys %{ $h->{'ALIGNMENTS'}{$align}{'species'} } ) {
      $wuc->modify_configs(
        ["synteny_$_"],
        {'display'=>'normal'}
      );
    }
  }
  
  return sprintf qq(
  <div class="autocenter navbar" style="width:%spx">
    <form action="%s" method="get"><div class="relocate">
      <label for="align">Alignment:<select name="align" id="align">%s
      </select>%s
      <input value="Go&gt;" type="submit" class="go-button" />
    </div></form>
  </div>),
    $image_width, 
    $url->[0],
    $options,
    $extra_inputs;
}


1;
