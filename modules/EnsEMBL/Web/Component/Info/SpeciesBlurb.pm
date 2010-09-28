package EnsEMBL::Web::Component::Info::SpeciesBlurb;

use strict;

use EnsEMBL::Web::Controller::SSI;

use base qw(EnsEMBL::Web::Component);


sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $species     = $hub->species;
  my $common_name = $hub->species_defs->get_config($species, 'SPECIES_COMMON_NAME');
  my $file        = "/ssi/species/about_$species.html";
  $species        =~ s/_/ /g;
  my $name_string = $common_name =~ /\./ ? "<i>$species</i>" : "$common_name (<i>$species</i>)";
  
  return "<h1>$name_string</h1>" . EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file); 
}

1;
