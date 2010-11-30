package LoadPlugins;

### Loop through the plugin directories, requiring files determined by the condition supplied.
### MUST be required rather than used. The require should be done at the point when the plugin code needs to be executed.
### SiteDefs MUST be used somewhere in the codebase before LoadPlugins is required for the first time.
###
### Usage:
###   require LoadPlugins;
###   LoadPlugins::plugin(sub { /\.pm$/; });

use strict;

use File::Find;

use SiteDefs;

sub plugin {
  my $condition   = shift || undef;
  my @plugin_dirs = map !/::/ && -e "$_/modules" ? "$_/modules" : (), reverse @{$SiteDefs::ENSEMBL_PLUGINS || []};
  
  unshift @INC, reverse @plugin_dirs;
  
  my $wanted = sub {
    if (!$condition || &$condition($_)) {
      my $dir  = $File::Find::topdir;
      my $file = $File::Find::name;
      
      (my $relative_file = $file) =~ s/^$dir\///;    
      (my $package = $relative_file) =~ s/\//::/g;
      $package =~ s/\.pm$//g;
      
      # Regex matches all namespaces which are EnsEMBL:: but not EnsEMBL::Web
      # Therefore the if statement is true for EnsEMBL::Web:: and Bio:: packages, which are the ones we need to overload
      if ($package !~ /^EnsEMBL::(?!Web)/) {
        no strict 'refs';
        
        # Require the base module first, unless it already exists
        if (!exists ${"$package\::"}{'ISA'}) {
          foreach (grep -e "$_/$relative_file", @SiteDefs::ENSEMBL_LIB_DIRS) {
            eval "require '$_/$relative_file'";
            warn $@ if $@;
            last if exists ${"$package\::"}{'ISA'};
          }
        }
        
        eval "require '$file'"; # Require the plugin module
        warn $@ if $@;
      }
    }
  };
  
  find($wanted, @plugin_dirs);
}

1;