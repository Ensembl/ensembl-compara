package EnsEMBL::Web::Component::Location::Compara_AlignSliceTop;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location::ViewTop);

use EnsEMBL::Web::Proxy::Object;
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub _extra {
  my( $self, $wuc, $slice ) = @_;

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
}

1;
