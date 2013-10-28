package LoadPlugins;

### Adds a subroutine in the @INC array that gets called everytime a file is 'require'd.
### The subroutine checks and loads (in the required order) all the files related to the file being required from the plugin directries after loading the core file
### SiteDefs MUST be used somewhere in the codebase before LoadPlugins is used since it needs to know about the ENSEMBL_LIB_DIRS and ENSEMBL_PLUGINS.

use strict;
use warnings;

use SiteDefs;

my $IMPORTED;

sub plugin {

  return if $IMPORTED;

  my @lib_dirs    = map [ 'core', $_ ], @SiteDefs::ENSEMBL_LIB_DIRS;
  my @all_plugins = reverse @{$SiteDefs::ENSEMBL_PLUGINS || []};
  my @plugins;

  while (my ($dir, $plugin_name) = splice @all_plugins, 0, 2) {
    push @plugins, [ $plugin_name, "$dir/modules" ] if -e "$dir/modules";
  }

  foreach my $index (0..1) {
    die qq(ERROR: Duplicate plugins found. Please check your conf/Plugins.pm\n) if @plugins != scalar keys %{{ map { $_->[$index] => 1 } @plugins }};
  }

  unshift @INC, sub {
    ## This subroutine gets called the first thing when we 'require' any package
    ## If a package can have plugins, it loads the core one first, and then loads any plugins if found
    my ($coderef, $filename) = @_;

    my @inc;

    return unless substr($filename, 0, 12) eq 'EnsEMBL/Web/' || substr($filename, 0, 4) eq 'Bio/';

    {
      local $SIG{'__WARN__'} = sub { warn $_[0] unless $_[0]=~ /Subroutine .+ redefined/; };

      for (@lib_dirs, @plugins) {
        my $filename  = "$_->[1]/$filename" =~ s/\/+/\//gr;
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

    # this is not really needed by perl afterwards, it's only for us to keep a
    # record of how many plugins does one particular file has
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