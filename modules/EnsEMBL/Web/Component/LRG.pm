# $Id$

package EnsEMBL::Web::Component::LRG;

use strict;

use Digest::MD5 qw(md5_hex);

use base qw(EnsEMBL::Web::Component);

sub ajax_url {
  my ($self, $function_name, $no_query_string) = @_;

  my $hub = $self->hub;
  my ($ensembl, $plugin, $component, $type, $module) = split '::', ref $self;

  my $url = join '/', $hub->species_defs->species_path, 'Component', $type, $plugin, $module;
  $url   .= "/$function_name" if $function_name && $self->can("content_$function_name");
  $url   .= '?_rmd=' . substr md5_hex($ENV{'REQUEST_URI'}), 0, 4;
  $url   .= ";$ENV{'QUERY_STRING'}" unless $no_query_string;

  return $url;
}

1;
