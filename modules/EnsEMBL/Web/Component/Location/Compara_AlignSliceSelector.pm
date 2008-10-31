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
  my $url = $self->object->_url({}, 1 );
  my $extra_inputs;
  foreach(sort keys %{$url->[1]||{}}) {
    $extra_inputs .= sprintf '
      <input type="hidden" name="%s" value="%s" />', escapeHTML($_),escapeHTML($url->[1]{$_});
  }

  my $options = '';
  my $species = $ENV{'ENSEMBL_SPECIES'};
  my $align = $self->object->param('align');
## Get the compara database hash!

  my $h = $self->object->species_defs->multi_hash->{'DATABASE_COMPARA'};
  my %a = %{$h->{'ALIGNMENTS'}||{}};
  my %x = ();
  foreach my $aa ( keys %a ) {
    next unless $a{$aa}{'species'}{$species};
    my $T = keys %{$a{$aa}{'species'}||{}};
    $x{$aa} = [ $a{$aa}{'name'}, $T ];
  }

  foreach ( sort { $x{$b}[1]<=>$x{$a}[1] || $x{$a}[0] cmp $x{$a}[0] } keys %x ) {
    $options .= sprintf '
        <option name="align" value="%d" %s>%s</option>',
      escapeHTML($_),
      $_ eq $align ? ' selected="selected"' :'',
      escapeHTML( $x{$_}[0] );
  }
  
## Get the species in the alignment and turn on the approriate Synteny tracks!
  
  return sprintf qq(
  <div class="autocenter navbar" style="width:%spx; text-align:left" >
    <form action="%s" method="get"><div style="padding:2px;">
      <label for="align">Alignment:</label> <select name="align" id="align">%s
      </select>%s
      <input value="Go&gt;" type="submit" class="go-button" />
    </div></form>
  </div>),
    $self->image_width, 
    $url->[0],
    $options,
    $extra_inputs;
}


1;
