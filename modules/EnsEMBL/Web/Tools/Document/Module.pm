package EnsEMBL::Web::Tools::Document::Module;

## Inside-out class for representing Perl modules.

#use strict;
use warnings;
use EnsEMBL::Web::Tools::Document::Method;

{

my %Methods_of;
my %Name_of;
my %Inheritance_of;
my %Subclasses_of;
my %Lines_of;
my %Location_of;
my %Overview_of;
my %Identifier_of;

my $default_comment_code = "##";

sub new {
  ## c
  ## Inside-out class for representing Perl modules.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Methods_of{$self} = defined $params{methods} ? $params{methods} : [];
  $Name_of{$self} = defined $params{name} ? $params{name} : "";
  $Inheritance_of{$self} = defined $params{inheritance} ? $params{inheritance} : [];
  $Subclasses_of{$self} = defined $params{subclasses} ? $params{subclasses} : [];
  $Location_of{$self} = defined $params{location} ? $params{location} : "";
  $Lines_of{$self} = defined $params{lines} ? $params{lines} : "";
  $Overview_of{$self} = defined $params{overview} ? $params{overview} : "";
  $Identifier_of{$self} = defined $params{identifier} ? $params{identifier} : $default_comment_code;
  if ($params{find_methods}) {
    $self->find_methods;
  }
  return $self;
}

sub coverage {
  my $self = shift;
  my $count = 0;
  my $total = 0;
  foreach my $method (@{ $self->all_methods }) {
    $total++;
    if ($method->type ne 'unknown') {
      $count++;
    }
  }
  if ($total == 0 ) {
    $coverage = 0;
  } else {
    $coverage = ($count / $total) * 100;
  }
  return $coverage;
}

sub module_coverage {
  my $self = shift;
  my $count = 0;
  my $total = 0;
  foreach my $method (@{ $self->methods }) {
    $total++;
    if ($method->type ne 'unknown') {
      $count++;
    }
  }
  if ($total == 0 ) {
    $coverage = "0";
  } else {
    $coverage = ($count / $total) * 100;
  }
  return $coverage;
}

sub types {
  ## Returns an array of all types of method.
  my $self = shift;
  my @types = ();
  my %type_count = ();
  foreach my $method (@{ $self->all_methods }) {
    if (! $type_count{$method->type}++ ) {
      push @types, $method->type;
    }
  }
  @types = sort @types;
  return \@types;
}

sub methods_of_type {
  ## Returns all methods of a particular type. Useful when used with
  ## types. Includes methods inherited from superclasses.
  my ($self, $type) = @_;
  my @methods = ();
  foreach my $method (@{ $self->all_methods }) {
    if ($method->type eq $type) {
      push @methods, $method;
    }
  }
  return \@methods;
}

sub find_methods {
  ## Scans package files for method definitions, and creates
  ## new method objects for each one found. Method object 
  ## references are stored in the methods array.
  my $self = shift;
  my %documentation = %{ $self->_parse_package_file };
  foreach my $method (keys %{ $documentation{methods} }) {
    my $new_method = EnsEMBL::Web::Tools::Document::Method->new((
                       name => $method,
                       documentation => $documentation{methods}{$method}->{comment},
                       type => $documentation{methods}{$method}->{type},
                       result => $documentation{methods}{$method}->{return},
                       module => $self
                     ));
    $self->add_method($new_method);
  }
  if ($documentation{isa}) {
    my @superclasses = split /\s+/, $documentation{isa};
    foreach $class (@superclasses) {
      $self->add_superclass($class);
    }
  }

  $self->overview_documentation($documentation{overview});

  if ($documentation{overview}) {
  #  $self->overview_documentation($documentation{overview});
  #  $self->overview_documentation("TEST");
    warn "HOVOVER: " . $self->name . " : " . $self->overview_documentation;
  }

}

sub _parse_package_file {
  ## Opens and parses Perl package files for methods and comments
  ## in e! doc format.
  my $self = shift;
  my %docs = ();
  open (my $fh, $self->location);
  my $sub = "";
  my $package = "";
  my $lines = "";
  my $comment_code = $self->identifier;
  while (<$fh>) {
    my $block = 0;
    $lines++;
    if (/\@ISA/) {
      my ($nothing, $isa) = split /=/; 
      if ($isa) { 
        $isa =~ s/qw|\(|\)|;//g;
        chomp $isa;
        $isa =~ s/\s+//g;
        $docs{isa} = $isa;
      }
    }

    if (/^package/) {
      $package = $_;
      $docs{overview} = "";
    }

    if ($package && $sub eq "" && /^##/) {
      #$docs{overview} .= $_;  
      #$docs{overview} = "found";
    } 

    if (/^sub /) { 
      $package = "";
      $sub = $_;
      $sub =~ s/^sub |{.*//g;
      $sub =~ s/\W+//g;
      if (!$docs{methods}) {
        $docs{methods} = {};
      }
      $docs{methods}{$sub} = {};
    }
    if ($sub && /$comment_code/) {
      my ($trash, $comment) = split /$comment_code/;
      $comment =~ s/^\s+|\s+$//g;
      chomp $comment;
      my @elements = split /\s+/, $comment;
      if (!$docs{methods}{$sub}{type}) {
        $docs{methods}{$sub}{type} = "method";
      }
      if ($#elements == 0) {
        $comment = $self->keywords($comment);
        $docs{methods}{$sub}{type} = lc($comment);
      } elsif ($#elements == 1) {
        if ($elements[0] =~ /eturn/) {
          $docs{methods}{$sub}{return} = $elements[1];
          #print "RETURN: " . $docs{$sub}{return} . "\n";
          $block = 1;
        }
      }
      $docs{methods}{$sub}{comment} .= " " . $comment if !$block;
      $block = 0;
    }
    if (/SUPER::/) {
      if (/->(.*)::(.*)\(/) {
        $docs{methods}{$sub}{super} = $2;
      } elsif (/->(.*)::(.*)\s+;/) {
        $docs{methods}{$sub}{super} = $2;
      }
    }
  }
  $self->lines($lines);
  return \%docs;
}

sub keywords {
  my ($self, $comment) = @_;
  my %keywords = qw(a accessor c constructor d destructor);
  my $return_keyword = $comment;
  if ($keywords{$comment}) {
    $return_keyword = $keywords{$comment};
    warn $return_keyword;
  }
  return $return_keyword;
}

sub add_method {
  ## Adds a method name to the method array.
  my ($self, $method) = @_;
  push @{ $self->methods }, $method;
}

sub name {
  ## a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub inheritance {
  ## a
  my $self = shift;
  $Inheritance_of{$self} = shift if @_;
  return $Inheritance_of{$self};
}

sub superclass {
  ## Convenience accessor for inheritance 
  return inheritance(@_);
}

sub location {
  ## a
  my $self = shift;
  $Location_of{$self} = shift if @_;
  return $Location_of{$self};
}

sub subclasses {
  ## a
  my $self = shift;
  $Subclasses_of{$self} = shift if @_;
  return $Subclasses_of{$self};
}

sub add_subclass {
  ## Adds a subclass to the subclass array.
  my ($self, $subclass) = @_;
  push @{ $self->subclasses }, $subclass;
}

sub add_superclass {
  ## Adds a superclass to the inheritance array.
  my ($self, $superclass) = @_;
  push @{ $self->inheritance}, $superclass;
}

sub all_methods {
  ## returns all methods from this class, and its superclasses.
  my $self = shift;
  my @return_methods = @{ $self->methods };
  foreach my $superclass (@{ $self->inheritance}) {
    push @return_methods, @{ $superclass->all_methods };    
  } 
  return \@return_methods; 
}

sub methods {
  ## a
  my $self = shift;
  $Methods_of{$self} = shift if @_;
  return $Methods_of{$self};
}

sub identifier {
  ## a
  my $self = shift;
  $Identifier_of{$self} = shift if @_;
  return $Identifier_of{$self};
}

sub lines {
  ## a
  my $self = shift;
  $Lines_of{$self} = shift if @_;
  return $Lines_of{$self};
}

sub overview_documentation {
  ## a
  my $self = shift;
  $Overview_of{$self} = shift if @_;
  return $Overview_of{$self};
}

sub DESTROY {
  ## d
  my $self = shift;
  delete $Methods_of{$self};
  delete $Name_of{$self};
  delete $Location_of{$self};
  delete $Subclasses_of{$self};
  delete $Lines_of{$self};
  delete $Overview_of{$self};
  delete $Identifier_of{$self};
}

}

1;
