package EnsEMBL::Web::Component::Info::SpeciesBlurb;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::Apache::SendDecPage;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}


sub content {
  my $self   = shift;
  my $object = $self->object;
  my $name_string;
  my $bio_name = $object->species;
  my $common_name = $object->species_defs->get_config($bio_name, 'SPECIES_COMMON_NAME');
  $bio_name =~ s/_/ /g;
  if ($common_name =~ /\./) {
    $name_string = "<i>$bio_name</i>";
  }
  else {
    $name_string = "$common_name (<i>$bio_name</i>)";
  }
  my $html = qq(<h1>$name_string</h1>); 

  my $file = '/ssi/species/about_'.$object->species.'.html';
  $html .= EnsEMBL::Web::Apache::SendDecPage::template_INCLUDE(undef, $file); 

  return $html;
}

1;
