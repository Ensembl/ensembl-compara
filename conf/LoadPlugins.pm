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

package LoadPlugins;

### Adds a subroutine in the @INC array that gets called everytime a file is 'require'd.
### The subroutine checks and loads (in the required order) all the files related to the file being required from the plugin directries after loading the core file
### SiteDefs MUST be used somewhere in the codebase before LoadPlugins is used since it needs to know about the ENSEMBL_LIB_DIRS and ENSEMBL_PLUGINS.

use strict;
use warnings;

use SiteDefs;

my $IMPORTED;
my %LOADING;

sub import {

  # Importing LoadPlugins more than once will pollute the @INC
  if ($IMPORTED) {
    my @caller = caller;
    warn qq(Useless attempt to import LoadPlugins at $caller[1] line $caller[2]\n);
    return;
  }

  my @lib_dirs    = map [ 'core', $_ ], @SiteDefs::ENSEMBL_LIB_DIRS;
  my @all_plugins = reverse @{$SiteDefs::ENSEMBL_PLUGINS || []};
  my @plugins;

  # Only need to plugin in the perl files inside the 'module' folders
  while (my ($dir, $plugin_name) = splice @all_plugins, 0, 2) {
    push @plugins, [ $plugin_name, "$dir/modules" ] if -e "$dir/modules";
  }

  # Duplicate plugins will cause problems
  foreach my $index (0..1) {
    die qq(ERROR: Duplicate plugins found. Please check your conf/Plugins.pm\n) if @plugins != scalar keys %{{ map { $_->[$index] => 1 } @plugins }};
  }

  unshift @INC, sub {
    ## This subroutine gets called the first thing when we 'require' any package
    ## If a package can have plugins, it loads the core one first, and then loads any plugins if found
    my ($coderef, $filename) = @_;

    my @inc;

    # We don't want to plugin any of the packages that don't start
    # with EnsEMBL::Web::, EnsEMBL::Draw or Bio::
    return unless substr($filename, 0, 12) eq 'EnsEMBL/Web/'
                    || substr($filename, 0, 13) eq 'EnsEMBL/Draw/'
                    || substr($filename, 0, 4) eq 'Bio/'
                    || substr($filename,0, 15) eq 'Sanger/Graphics';

    # If the file being plugged in (file A) has circular dependency with
    # another file (B) in the core code or any of the plugins, then while
    # requiring file A in the second attempt (when called from inside B)
    # we don't actually want to require the file (or any of it's plugins)
    # again. We don't even want to set the INC for file A since it will
    # tell perl to not requiring it at all (we'll set INC later in the
    # end when all files are loaded successfully).
    return sub { $_ = 1; delete $INC{$filename}; return 0; } if exists $LOADING{$filename};

    # Set the flag before loading
    $LOADING{$filename} = 1;

    {
      local $SIG{'__WARN__'} = sub { warn $_[0] unless $_[0]=~ /Subroutine .+ redefined/; };

      # Load the core file first, then all the existing plugin files
      for (reverse(@lib_dirs), @plugins) {
        my $filename = "$_->[1]/$filename" =~ s/\/+/\//gr;
        if (-e $filename) {
          eval "require '$filename'";
          if ($@) {
            warn $@;
          } else {
            push @inc, [ $_->[0], $filename ];
          }
        }
      }
    }

    # Unset the flag once loading is complete
    delete $LOADING{$filename};

    # We need to set INC since we may have removed it in case of circular
    # dependency. The extra info that we provide here is not really needed
    # by perl afterwards, it's only for us to keep a record of how many
    # plugins does one particular file have.
    # See EnsEMBL::Web::Tools::PluginInspector
    if (@inc) {
      if (@inc == 1 && $inc[0][0] eq 'core') {
        $INC{$filename} = $inc[0][1];
      } else {
        $INC{$_} = \@inc for map($_->[1], @inc), $filename;
      }
      return sub { $_ = 1; return 0; };
    }
  }, map($_->[1], @plugins);

  $IMPORTED = 1;
}

1;
