=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

You shouldn't create an EnsEMBL::Root object,
but should inherit it in other modules - it is really
just a container for support functions.

=cut

package EnsEMBL::Root;

### Root object for all EnsEMBL modules, containing some basic helper functions
### You should never instantiate it directly, only inherit it.

use strict;
use warnings;
no warnings 'uninitialized';

use Carp qw(cluck);
use Data::Dumper;

use EnsEMBL::Web::Utils::DynamicLoader qw(%_INC);
use EnsEMBL::Web::Utils::FileSystem qw(create_path);

BEGIN {
# Used to enable symbolic debugging support in dynamic_use.
  if($ENV{'PERLDB'}) {
    require Inline;

    my $cbuild_dir = $SiteDefs::ENSEMBL_CBUILD_DIR;
    create_path($cbuild_dir) unless -e $cbuild_dir;

    Inline->import(C => Config => DIRECTORY => $cbuild_dir);
    Inline->import(C => "void lvalues_nodebug(CV* cv) { CvNODEBUG_on(cv); }");
  }
}

# SOME_ ie. those known to dynamic_use to be successfully loaded either
#   by itself, or discovered during attempts to require them. Being in this
#   hash means that it /is/ definitely already loaded. Not being in it says
#   nothing. As this is the most common case it's a great speedup to cache
#   this.

sub new {
### Stub - do not instantiate this module directly!
  my $class = shift;
  my $self  = {};
  bless $self, $class;
  return $self;
}

sub datadump {
### Handy wrapper around Data::Dumper that tells you where the dump is being called
  my $self = shift;
  my $i=0;
  warn Data::Dumper::Dumper( @_ ? [@_] : $self );
  while( my @Q = caller(++$i) ) {
    warn "  at $Q[3] (file $Q[1] line $Q[2])\n"; 
  }
}

sub dynamic_use {
###  Requires, and imports the methods for the classname provided,
###  checks the symbol table so that it doesn't re-require modules
###  that have already been required.

###  @param       String $classname - the name of the class to "use"
###  @return      Integer - 1 if successful, 0 if failure
  my ($self, $classname) = @_;

  if (!$classname) {
    my @caller = caller(0);
    my $error_message = "Dynamic use called from $caller[1] (line $caller[2]) with no classname parameter\n";
    warn $error_message;
    $_INC{$classname} = $error_message;
    return 0;
  }

  my $inc_filename = $classname.".pm";
  $inc_filename =~ s!::!/!g;

  unless(exists $_INC{$classname}) {
    eval "require $classname";

    if ($@) {
      my $path = $classname;
      $path =~ s/::/\//g;

      cluck "EnsEMBL::Web::Root: failed to use $classname\nEnsEMBL::Web::Root: $@" unless $@ =~ /^Can't locate $path/;

      $_INC{$classname} = $@;
      $@ = undef;
      return 0;
    } else {
      $_INC{$classname} = 0;
    }
  }
  if(!$_INC{$classname}) {
    $classname->import;
    return 1;
  } else {
    return 0;
  }
}

sub dynamic_use_fallback {
### Tries to dynamically use the first possible module out of a list of given modules
### @param   list of modules' name (Array, not ArrayRef)
### @return  first successfully "use"d module's name
  my $self    = shift;
  my $module  = shift;
  $module     = shift while $module && !$self->dynamic_use($module);
  return $module;
}

sub dynamic_use_failure {
### Return error message cached if use previously failed
  my ($self, $classname) = @_;
  return $_INC{$classname};
}

######### PRIVATE METHODS ################

# Hack to allow symbollic debugging in face of lvalues,
# despite perl bug #7013. Only run when in debug mode.
sub _fix_lvalues_r {
  no strict;
  my ($name,$here) = @_;

  foreach my $t (values %$here) {
    next unless *{"$t"}{CODE} and grep { $_ eq 'lvalue' } attributes::get(*{"$t"}{CODE});
    lvalues_nodebug(*{"$t"}{CODE});
  }
  _fix_lvalues_r("$name$_",\%{"$name$_"}) for keys %$here;
}
sub _fix_lvalues {
  no strict;
  my $classname = shift;
  _fix_lvalues_r("EnsEMBL::",\%{"EnsEMBL::"});
}
# End hack

1;
