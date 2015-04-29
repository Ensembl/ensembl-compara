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

package EnsEMBL::eDoc::Generator;

### A module to automatically generate documentation in e!doc format
### Usually called from ensembl-webcode/utils/edoc/generate_edoc.pl

use strict;
use warnings;
use EnsEMBL::eDoc::Module;
use EnsEMBL::eDoc::Writer;
use File::Find;

sub new {
  ### c
  my ($class, %params) = @_;
  my $writer = new EnsEMBL::eDoc::Writer;
  my $self = {
    'directories' => $params{'directories'} || [],
    'module_info' => $params{'module_info'} || {},
    'keywords'    => $params{'keywords'}    || '',
    'serverroot'  => $params{'serverroot'}  || '',
    'version'     => $params{'version'}     || 'master',
    'writer'      => $writer,
  };
  bless $self, $class;
  if ($self->{'serverroot'}) {
    $writer->serverroot($self->{'serverroot'});
  }
  return $self;
}

sub directories {
  ## @accessor
  ## @return Arrayref
  my $self = shift;
  return $self->{'directories'};
}

sub module_info {
  ## @accessor
  ## @return Hashref
  my $self = shift;
  return $self->{'module_info'};
}

sub module_names {
  ## @accessor
  ## @return Array of strings
  my $self = shift;
  return keys %{$self->{'modules'}};
}

sub modules {
  ## @accessor
  ## @return Arrayref of EnsEMBL::eDoc::Module objects
  my $self = shift;
  my $modules = [];
  my @values = values %{$self->{'modules'}};
  foreach (@values) {
    push @$modules, @$_;
  }
  return $modules;
}

sub modules_by_name {
  ## @accessor
  ## @return EnsEMBL::eDoc::Module 
  my ($self, $name) = @_;
  return $self->{'modules'}{$name};
}

sub keywords {
  ## @accessor
  ## @return Hashref
  my $self = shift;
  return $self->{'keywords'};
}

sub serverroot {
  ## @accessor
  ## @return String
  my $self = shift;
  return $self->{'serverroot'};
}

sub version {
  ## @accessor
  ## @return Integer (Ensembl version)
  my $self = shift;
  return $self->{'version'};
}

sub writer {
  ## @accessor
  ## @return EnsEMBL::eDoc::Writer
  my $self = shift;
  return $self->{'writer'};
}

sub find_modules {
  ### Recursively finds modules located in all directories
  my ($self, $server_root) = @_;
  my $code_ref = sub { $self->wanted($server_root) };
  find($code_ref, @{$self->directories});

  # map inheritance (super and sub classes), and replace module
  # names with module objects.
  my %subclasses = ();

  foreach my $module (@{$self->modules}) {
    if ($module->inheritance) {
      my @class_cache = ();
      foreach my $classname (@{ $module->inheritance }) {
        push @class_cache, $classname;
      }

      $module->inheritance([]);

      foreach my $classname (@class_cache) {
        my $superclass_array = $self->modules_by_name($classname);
        next unless $superclass_array;
        my $superclass = $superclass_array->[0];
        if ($superclass) {
          $module->add_superclass($superclass);
          if (!$subclasses{$superclass->name}) {
            $subclasses{$module->name} = [];
          }
          push @{ $subclasses{$superclass->name} }, $module;
        }
      }
    }
  }

  foreach my $module_name (keys %subclasses) {
    my @modules = @{$self->modules_by_name($module_name)};
    foreach my $module (@modules) {
      my @subclasses = @{ $subclasses{$module_name} };
      if (@subclasses) {
        foreach my $subclass (@subclasses) {
          $module->add_subclass($subclass);
        }
      }
    }
  }

  return $self->modules;
}

sub wanted {
  ### Callback method used to find packages in the directory of
  ### interest.
  my ($self, $server_root) = @_;
  if ($File::Find::name =~ /pm$/) {
    #print "Indexing " . $_ . "\n";
    #warn "CHECKING: " . $File::Find::name;
    my $class = $self->_package_name($File::Find::name);
    (my $path = $File::Find::name) =~ s/$server_root//;
    $path =~ /\/public-plugins\/([a-zA-Z]+)\/modules/;
    $self->_add_module($class, $File::Find::name, $1);
  }
}

sub generate_html {
  ## Call all the Writer methods used to output the eDoc HTML pages
  ## @return Void
  my ($self, $location, $base, $support) = @_;

  my $writer = $self->writer;
  $writer->location($location);
  $writer->support($support);
  $writer->base($base);

  $writer->write_info_page($self->modules);
  $writer->write_package_frame($self->modules);
  $writer->write_method_frame($self->methods);
  $writer->write_base_frame($self->modules);
  $writer->write_module_pages($self->modules, $self->version);
  $writer->write_frameset;
}

sub methods {
  ### Collects a list of all methods in all found modules
  ### @return Arrayref of EnsEMBL::eDoc::Method objects
  my $self = shift;
  my @methods = ();
  foreach my $module (@{$self->modules}) {
    foreach my $method (@{ $module->methods }) {
      #warn $method;
      push @methods, $method;
    }
  }
  return \@methods;
}

sub _package_name {
  ### Reads package name from .pm file
  ### @return String
  my ($self, $filename) = @_;
  open (my $fh, $filename) or die "$!: $filename";
  my $package = '';
  while (<$fh>) {
    if (/^package/) {
      $package = $_;
      chomp $package;
      $package =~ s/package |;//g;
      last;
    }
  }
  close $fh;
  return $package;
}


sub _add_module {
  ## Adds a new module object to the array of found modules.
  ## The new module will find methods within that package on
  ## instantiation.
  ## @return Void
  my ($self, $class, $location, $plugin) = @_;
  my $module = EnsEMBL::eDoc::Module->new(
                     name         => $class,
                     location     => $location,
                     plugin       => $plugin,
                     keywords     => $self->keywords,
                     find_methods => 1,
                   );
  #print "ADDING: $class $module\n";
  my $arrayref = $self->modules_by_name($class);
  if ($arrayref) {
    push @$arrayref, $module;
  }
  else {
    $self->{'modules'}{$class} = [$module];
  }
}

1;
