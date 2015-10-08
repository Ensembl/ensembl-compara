=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
our @EXPORT_OK = qw(get_all_plugins get_file_plugins current_plugin previous_plugin next_plugin); # And more?

sub current_plugin {
  ## Gets the current plugin package and path name
  my $caller  = [ caller ]->[1];
  my $plugins = __PACKAGE__->get_all_plugins;

  return first { $caller =~ /^$_->{path}/} @$plugins;
}

sub get_all_plugins {
  ## Gets a list of all active plugins
  ## @return Ref to an ordered array of hashes (Each hash corresponds to individual plugin and contains 'path' and 'package' key)
  my $plugins = $SiteDefs::ENSEMBL_PLUGINS;
  my @plugins;

  for (my $i = 0; $plugins->[$i]; $i += 2) {
    push @plugins, { 'package' => $plugins->[$i], 'path' => $plugins->[$i+1] };
  }

  return \@plugins;
}

sub get_file_plugins {}

sub previous_plugin {}

sub next_plugin {}

1;
