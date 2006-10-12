package EnsEMBL::Web::Tools::Document;

use strict;
use warnings;
use EnsEMBL::Web::Tools::Document::Module;
use EnsEMBL::Web::Tools::Document::Method;
use EnsEMBL::Web::Tools::DocumentView;
use File::Find;

{

my %Directory_of;
my %Modules_of;
my %Identifier_of;
my %Keywords_of;
my %ServerRoot_of;
my $writer = EnsEMBL::Web::Tools::DocumentView->new;

sub new {
  ### c
  ### Inside-out class for automatically generating documentation in 
  ### e! doc format.
  ###
  ### A new line
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Directory_of{$self} = defined $params{directory} ? $params{directory} : [];
  $Modules_of{$self} = defined $params{modules} ? $params{modules} : [];
  $Identifier_of{$self} = defined $params{identifier} ? $params{identifier} : "##";
  $Keywords_of{$self} = defined $params{keywords} ? $params{keywords} : ();
  $ServerRoot_of{$self} = defined $params{server_root} ? $params{server_root} : "";
  if ($self->server_root) {
    $writer->server_root($self->server_root);
  }
  return $self;
}

sub find_modules {
  ### Recursively finds modules located in the directory parameter.
  my $self = shift;
  my $code_ref = sub { $self->wanted(@_) };
  find($code_ref, @{ $self->directory });   
 
  # map inheritance (super and sub classes), and replace module
  # names with module objects.
  my %subclasses = ();
  foreach my $module (@{ $self->modules }) {
    if ($module->inheritance) {
      my @class_cache = ();
      foreach my $classname (@{ $module->inheritance }) {
        push @class_cache, $classname;
      }
      
      $module->inheritance([]);
    
      foreach my $classname (@class_cache) {
        my $superclass = $self->module_by_name($classname);
        if ($superclass) {
          $module->add_superclass($superclass);
          if (!$subclasses{$superclass->name}) {  
            $subclasses{$module->inheritance} = [];
          }
          push @{ $subclasses{$superclass->name} }, $module; 
        }
      }

    }
  }

  foreach my $module_name (keys %subclasses) {
    my $module = $self->module_by_name($module_name);
    if ($module) {
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

sub module_by_name {
  ### Returns a module object ({{EnsEMBL::Web::Tools::Document::Module}}) for a given fully qualified name. 
  my ($self, $name) = @_;
  my $return = 0;
  foreach my $module (@{ $self->modules }) {
    if ($module->name eq $name) {
      $return = $module;
      last;
    }
  }
  return $return; 
}

sub wanted {
  ### Callback method used to find packages in the directory of
  ### interest.
  my $self = shift;
  if ($File::Find::name!~ /CVS/ && $_ =~ /pm$/) {
    print "Indexing " . $_ . "\n";
    #warn "CHECKING: " . $File::Find::name;
    my $package = $self->_package_name($File::Find::name);
    $self->_add_module($package, $File::Find::name);
  }
}

sub _add_module {
  ### Adds a new module object to the array of found modules.
  ### The new module will find methods within that package on
  ### instantiation.
  my ($self, $module, $location) = @_;
  my $new_module = EnsEMBL::Web::Tools::Document::Module->new((
                     name => $module,
                     location => $location,
                     identifier => $self->identifier,
                     keywords => $self->keywords,
                     find_methods => "yes"
                   ));
  #warn "ADDING: " . $new_module->name;
  push @{ $self->modules }, $new_module;
}

sub _package_name {
  ### (filename) Reads package name from .pm file
  ### Returns $package
  my ($self, $filename) = @_;
  open (my $fh, $filename) or die "$!: $filename";
  my $package = "";
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


sub generate_html {
  ### (location) Writes HTML documentation to specified export location.
  my ($self, $location, $base, $support) = @_;
  $writer->location($location);
  $writer->support($support);
  $writer->base_url($base);

  $writer->write_info_page($self->modules);
  $writer->write_package_frame($self->modules);
  $writer->write_method_frame($self->methods);
  $writer->write_base_frame($self->modules);
  $writer->write_module_pages($self->modules);
  $writer->write_frameset;

  $writer->copy_support_files;
}

sub directory {
  ### a
  my $self = shift;
  $Directory_of{$self} = shift if @_;
  return $Directory_of{$self};
}

sub modules {
  ### a
  my $self = shift;
  $Modules_of{$self} = shift if @_;
  return $Modules_of{$self};
}

sub identifier {
  ### a
  my $self = shift;
  $Identifier_of{$self} = shift if @_;
  return $Identifier_of{$self};
}

sub keywords {
  ### a
  my $self = shift;
  $Keywords_of{$self} = shift if @_;
  return $Keywords_of{$self};
}

sub server_root {
  ### a
  my $self = shift;
  $ServerRoot_of{$self} = shift if @_;
  return $ServerRoot_of{$self};
}

sub methods {
  ### Returns all method objets for all found modules
  my $self = shift;
  my @methods = ();
  foreach my $module (@{ $self->modules }) {
    #warn $module->name;
    foreach my $method (@{ $module->methods }) {
      #warn $method;
      push @methods, $method;
    }
  }
  return \@methods;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Directory_of{$self};
  delete $Modules_of{$self};
  delete $Identifier_of{$self};
  delete $Keywords_of{$self};
  delete $ServerRoot_of{$self};
}

}

1;
