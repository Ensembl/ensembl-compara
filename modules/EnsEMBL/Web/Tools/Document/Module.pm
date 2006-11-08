package EnsEMBL::Web::Tools::Document::Module;

### Inside-out class for representing Perl modules.

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
my %Keywords_of;

my $default_comment_code = "###";
my $default_keywords = "a accessor c constructor d desctructor x deprecated i initialiser";

sub new {
  ### c
  ### Inside-out class for representing Perl modules.
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
  $Keywords_of{$self} = defined $params{keywords} ? $params{keywords} : $default_keywords;
  if ($params{find_methods}) {
    $self->find_methods;
  }
  return $self;
}

sub coverage {
  ### Calculates and returns the documentation coverage for all callable methods in a module. This includes any inherited methods. Use {{module_coverage}} to calculate the documentation coverage for a module's methods only.

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
  ### Calculates and returns the documentation coverage for a module's methods. This does not include inherited methods (see {{coverage}}).
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
  ### Returns an array of all types of methods.
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
  ### Returns all methods of a particular type. Useful when used with
  ### types. Includes methods inherited from superclasses.
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
  ### Scans package files for method definitions, and creates
  ### new method objects for each one found. Method object 
  ### references are stored in the methods array.
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
    if ($documentation{table}{$method}) {
      $new_method->table($documentation{table}{$method});
    }
    $self->add_method($new_method);
  }
  if ($documentation{isa}) {
    my @superclasses = split /\s+/, $documentation{isa};
    foreach $class (@superclasses) {
      $self->add_superclass($class);
    }
  }


  if ($documentation{overview}) {
     $self->overview($documentation{overview});
  }

}

sub _parse_package_file {
  ### Opens and parses Perl package files for methods and comments
  ### in e! doc format.
  my $self = shift;
  my %docs = ();
  open (my $fh, $self->location);
  my $sub = "";
  my $package = "";
  my $lines = "";
  my $comment_code = $self->identifier;
  my $table = 0;
  my $block_table = 0;
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

    if ($package && $sub eq "" && /^$comment_code /) {
      my $temp = $_;
      $temp =~ s/$comment_code//g;
      $docs{overview} .= $temp;  
    } 

    if (/^sub /) { 
      $package = "";
      $sub = $_;
      $sub =~ s/^sub |{.*//g;
      $sub =~ s/:lvalue//; ## REALLY NEED TO SET A FLAG HERE FOR LVALUE FUNCTIONS....
      $sub =~ s/\W+//g;
      if (!$docs{methods}) {
        $docs{methods} = {};
      }
      $table = "";
      $docs{methods}{$sub} = {};
      $docs{table}{$sub} = {};
    }
    if ($sub && /$comment_code/) {
      my ($trash, $comment) = split /$comment_code/;
      $comment =~ s/^\s+|\s+$//g;
      chomp $comment;
      if ($comment eq "") {
        $comment .= "<br /><br />";
        $table = "";
      }
      
      if ($comment eq "___") {
         if ($block_table) {
           $block_table = 0;
         } else {
           $block_table = 1;
         }
      }

      if ($comment =~ /[A-Z].*\s*:\s+\w+/) {
        if (!$block_table) {
          ($table, $trash) = split(/:/, $comment);
        }
      }
      if ($table) {
        if ($comment !~ /^.eturns:/) {
          my $table_content = $comment;
          $table_content =~ s/$table\s*://;
          if (!$docs{table}{$sub}->{$table}) {
            $docs{table}{$sub}->{$table} = ""; 
          }
          $docs{table}{$sub}->{$table} .= $table_content . " ";
          $block = 1;
        }
      }

      my @elements = split /\s+/, $comment;
      if (!$docs{methods}{$sub}{type}) {
        $docs{methods}{$sub}{type} = "method";
      }
      if ($#elements == 0 and $comment ne '___') {
        $comment = ucfirst($self->convert_keyword($comment));
        $docs{methods}{$sub}{type} = lc($comment);
        $comment .= ". ";
      } else {
        if ($elements[0] =~ /^.eturns/) {
          $docs{methods}{$sub}{return} = "@elements";
          $table = "";
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

sub convert_keyword {
  ### Accepts a single abbreviation and returns its long form. This method is called on all lines that contain a single word, and replaces shorcuts with longer descriptions. For example, 'a' is elongates to 'accessor'. Keywords can be specified using {keyword}. 
  my ($self, $comment) = @_;
  my %keywords = split / /, $self->keywords; 
  my $return_keyword = $comment;
  if ($keywords{$comment}) {
    $return_keyword = $keywords{$comment};
    #warn $return_keyword;
  }
  return $return_keyword;
}

sub add_method {
  ### Adds a method name to the method array.
  my ($self, $method) = @_;
  push @{ $self->methods }, $method;
}

sub keywords {
  ### a
  ### Accepts a string with key-value pairings, a la qw(). For example: 'a accessor c constructor d destructor'.
  my $self = shift;
  $Keywords_of{$self} = shift if @_;
  return $Keywords_of{$self};
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub inheritance {
  ### a
  my $self = shift;
  $Inheritance_of{$self} = shift if @_;
  return $Inheritance_of{$self};
}

sub superclass {
  ### Convenience accessor for inheritance 
  return inheritance(@_);
}

sub location {
  ### a
  my $self = shift;
  $Location_of{$self} = shift if @_;
  return $Location_of{$self};
}

sub subclasses {
  ### a
  my $self = shift;
  $Subclasses_of{$self} = shift if @_;
  return $Subclasses_of{$self};
}

sub add_subclass {
  ### Adds a subclass to the subclass array.
  my ($self, $subclass) = @_;
  push @{ $self->subclasses }, $subclass;
}

sub add_superclass {
  ### Adds a superclass to the inheritance array.
  my ($self, $superclass) = @_;
  push @{ $self->inheritance}, $superclass;
}

sub all_methods {
  ### returns all methods from this class, and its superclasses.
  my $self = shift;
  my @return_methods = @{ $self->methods };
  foreach my $superclass (@{ $self->inheritance}) {
    push @return_methods, @{ $superclass->all_methods };    
  } 
  return \@return_methods; 
}

sub methods {
  ### a
  my $self = shift;
  $Methods_of{$self} = shift if @_;
  return $Methods_of{$self};
}

sub identifier {
  ### a
  my $self = shift;
  $Identifier_of{$self} = shift if @_;
  return $Identifier_of{$self};
}

sub lines {
  ### a
  my $self = shift;
  $Lines_of{$self} = shift if @_;
  return $Lines_of{$self};
}

sub overview_documentation {
  ### a
  my $self = shift;
  $Overview_of{$self} = shift if @_;
  return $Overview_of{$self};
}

sub overview {
  ### a
  my $self = shift;
  $Overview_of{$self} = shift if @_;
  return $Overview_of{$self};
}

sub DESTROY {
  ### d
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
