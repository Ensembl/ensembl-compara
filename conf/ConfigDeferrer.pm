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

=cut

package ConfigDeferrer;

### Helper package to provide a mechanism to defer setting any SiteDefs config until all plugins SiteDefs are loaded

use strict;
use warnings;

use Exporter qw(import);
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

our @EXPORT_OK    = qw(defer register_deferred_configs build_deferred_configs required validate_required_configs);
our %EXPORT_TAGS  = ('all' => [ @EXPORT_OK ]);
our $DEBUG;
my (@DEFERRED_CONFIGS, @DEFERRED_VARS_LIST, %DEFERRED_VARS_MAP, %REQUIRED_CONFIGS);

sub defer (&) {
  ## Subroutine to be used to declare the configs that should be set once all plugins are loaded
  my ($conf) = @_;
  push @DEFERRED_CONFIGS, "$conf";
  return $conf;
}

sub required {
  ## Subroutine to be used to declare the configs that needs to be redeclared in another plugin
  my $val = '__UNDECLARED_REQUIRED_CONFIG__';

  if (@_) {
    $val .= sprintf '(%s)', md5_hex(sprintf '%s%s%s', caller);
    $REQUIRED_CONFIGS{$val} = $_[0];
  }

  return $val;
}

sub register_deferred_configs {
  ## Subroutine to be called after loading each plugin's SiteDefs to register all the deferred configs in that plugin
  my $package = shift || caller;

  {
    no strict qw(refs);

    # if one of the variables that was previously deferred is now declared in another plugin, remove it from deferred list
    foreach my $sym_name (@DEFERRED_VARS_LIST) {
      my $sym = *$sym_name;
      unless (*{$sym}{'SCALAR'} && ref *{$sym}{'SCALAR'} eq 'REF' && ref $$sym eq 'CODE') {
        delete $DEFERRED_VARS_MAP{$sym_name};
      }
    }

    # go through all the possible variables and add the ones to the deferred list that have a code ref matching in @DEFERRED_CONFIGS
    for (sort keys %{$package.'::'}) {
      my $sym_name  = "${package}::$_";
      my $sym       = *$sym_name;
      next unless ref(\$sym) eq 'GLOB';
      if (*{$sym}{'SCALAR'} && ref *{$sym}{'SCALAR'} eq 'REF' && grep {$_ eq "$$sym"} @DEFERRED_CONFIGS) {
        push @{$DEFERRED_VARS_MAP{$sym_name}}, $$sym;
      }
    }
  }

  # keep the order, in which the variables were declared, preserved
  foreach my $coderef (@DEFERRED_CONFIGS) {
    foreach my $sym_name (keys %DEFERRED_VARS_MAP) {
      if (grep({"$_" eq "$coderef"} @{$DEFERRED_VARS_MAP{$sym_name}}) && !grep({$_ eq $sym_name} @DEFERRED_VARS_LIST)) {
        push @DEFERRED_VARS_LIST, $sym_name;
      }
    }
  }

  @DEFERRED_CONFIGS = ();
}

sub build_deferred_configs {
  ## Subroutine to be called once all plugins are loaded to finally build the deferred configs
  my $package = shift || caller;

  {
    no strict qw(refs);

    foreach my $sym_name (@DEFERRED_VARS_LIST) {
      my $sym = *$sym_name;
      for (@{$DEFERRED_VARS_MAP{$sym_name}}) {
        $$sym = $_->();
        warn sprintf "ConfigDeferrer: %s = %s\n", $sym_name, "$$sym" if $DEBUG;
      }
    }
  }

  @DEFERRED_CONFIGS = @DEFERRED_VARS_LIST = %DEFERRED_VARS_MAP = ();
}

sub validate_required_configs {
  ## Subroutine to be called once all plugins are loaded and all deferred configs are built to finally check if any required config variable is left unassigned
  my $package = shift || caller;

  my @missing;

  {
    no strict qw(refs);

    for (sort keys %{$package.'::'}) {
      my $sym_name  = "${package}::$_";
      my $sym       = *$sym_name;
      next unless ref(\$sym) eq 'GLOB';

      if (defined $$sym && !ref $$sym && !index("$$sym", required())) {
        push @missing, {$sym_name, $REQUIRED_CONFIGS{"$$sym"}};
      }
    }
  }

  die(sprintf("Following config%s %s required. Please declare in your plugin's SiteDefs.\n%s\n", @missing > 1 ? ('s', 'are') : ('', 'is'), join("\n", map { my ($k) = keys %$_; sprintf ($_->{$k} ? '  $%s = %s;' : '  $%s', $k, _str($_->{$k}))} @missing))) if @missing;
}

sub _str {
  ## @private
  my $ref = shift;

  return ref $ref ? Data::Dumper->new([ $ref ])->Sortkeys(1)->Useqq(1)->Terse(1)->Indent(0)->Maxdepth(0)->Dump  : "'$ref'";
}

1;
