=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Utils::PluginInspector;

use strict;
use warnings;

use List::Util qw(first);

use Exporter qw(import);
our @EXPORT_OK = qw(get_all_plugins get_file_plugins current_plugin previous_plugin next_plugin);

sub get_all_plugins {
  ## Gets a list of all active plugins
  ## @return Ref to an ordered array of hashes (Each hash corresponds to individual plugin and contains 'path' and 'package' key)
  my @plugins = reverse @{$SiteDefs::ENSEMBL_PLUGINS};
  my $plugins = [{ 'path' => $SiteDefs::ENSEMBL_WEBROOT, 'package' => 'ensembl-webcode' }];

  for (my $i = 0; $plugins[$i]; $i += 2) {
    push @$plugins, { 'path' => $plugins[$i], 'package' => $plugins[$i+1] };
  }

  return $plugins;
}

sub get_file_plugins {
  ## Gets list of all the plugins for the calling file
  ## @return Ref to an ordered array of hashes (Each hash corresponds to individual plugin in which the calling file exists and contains 'file_path', 'path' and 'package' key)
  my $caller  = $_[1] || [ caller ]->[1];
  my %plugins = map { $_->{'package'} => $_ } @{__PACKAGE__->get_all_plugins};
  my $plugins = ref $INC{$caller} eq 'ARRAY' ? $INC{$caller} : [[ 'core', $INC{$caller} ]];

  return [ map { { 'file_path' => $_->[1], %{$plugins{$_->[0]}} } } @$plugins ];
}

sub current_plugin {
  ## Gets the current plugin package and path name
  ## @return Hashref with keys 'path' and 'package'
  my $caller = [ caller ]->[1];

  for (@{__PACKAGE__->get_file_plugins($caller)}) {
    return $_ if $caller eq $_->{'file_path'};
  }
}

sub previous_plugin {
  ## Gets the current plugin package and path name
  ## @return Hashref with keys 'file_path', 'path' and 'package' if previous plugin exists, undef otherwise
  my $caller = [ caller ]->[1];
  my $previous;

  for (@{__PACKAGE__->get_file_plugins($caller)}) {
    last if $caller eq $_->{'file_path'};
    $previous = $_;
  }

  return $previous;
}

sub next_plugin {
  ## Gets the current plugin package and path name
  ## @return Hashref with keys 'file_path', 'path' and 'package' if next plugin exists, undef otherwise
  my $caller = [ caller ]->[1];
  my $next;

  for (reverse @{__PACKAGE__->get_file_plugins($caller)}) {
    last if $caller eq $_->{'file_path'};
    $next = $_;
  }

  return $next;
}

1;
