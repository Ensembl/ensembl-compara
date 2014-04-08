=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::eDoc::Module;

use strict;
use warnings;

use EnsEMBL::eDoc::Method;

sub new {
  my ($class, %params) = @_;
  my $keywords = {'a' => 'accessor',
                  'c' => 'constructor',
                  'd' => 'destructor',
                  'h' => 'html',
                  'x' => 'deprecated',
                  'i' => 'initialiser',
                  };
  my $self = {
    'methods'     => $params{'methods'}     || [],
    'name'        => $params{'name'}        || '',
    'inheritance' => $params{'inheritance'} || [],
    'subclasses'  => $params{'subclasses'}  || [],
    'location'    => $params{'location'}    || '',
    'lines'       => $params{'lines'}       || '',
    'overview'    => $params{'overview'}    || '',
    'identifier'  => '#{2,3}',
    'keywords'    => $params{'keywords'}    || $keywords,
  };
  bless $self, $class;
  if ($params{'find_methods'}) {
    $self->find_methods;
  }
  return $self;
}

sub methods {
  my $self = shift;
  return $self->{'methods'};
}

sub methods_of_type {
  ### Returns all methods of a particular type. Useful when used with
  ### types. Includes methods inherited from superclasses.
  my ($self, $type) = @_;
  my @methods = ();
  foreach my $method (@{ $self->methods }) {
    if ($method->type eq $type) {
      push @methods, $method;
    }
  }
  return \@methods;
}

sub types {
  ### Returns an array of all types of methods.
  my $self = shift;
  my @types = ();
  my %type_count = ();
  foreach my $method (@{ $self->methods }) {
    if (! $type_count{$method->type}++ ) {
      push @types, $method->type;
    }
  }
  @types = sort @types;
  return \@types;
}


sub name {
  my $self = shift;
  return $self->{'name'};
}

sub inheritance {
  my ($self, $inheritance) = @_;
  $self->{'inheritance'} = $inheritance if $inheritance;
  return $self->{'inheritance'};
}

sub subclasses {
  my $self = shift;
  return $self->{'subclasses'};
}

sub location {
  my $self = shift;
  return $self->{'location'};
}

sub lines {
  my ($self, $lines) = @_;
  $self->{'lines'} = $lines if $lines;
  return $self->{'lines'};
}

sub overview {
  my ($self, $overview) = @_;
  $self->{'overview'} = $overview if $overview;
  return $self->{'overview'};
}

sub identifier {
  my $self = shift;
  return $self->{'identifier'};
}

sub keywords {
  my $self = shift;
  return $self->{'keywords'};
}

sub add_subclass {
  ### Adds a subclass to the subclass array.
  my ($self, $subclass) = @_;
  push @{$self->subclasses}, $subclass;
}

sub add_superclass {
  ### Adds a superclass to the inheritance array.
  my ($self, $superclass) = @_;
  push @{$self->inheritance}, $superclass;
}

sub find_methods {
  ### Scans package files for method definitions, and creates
  ### new method objects for each one found. Method object 
  ### references are stored in the methods array.
  my $self = shift;
  my %documentation = %{ $self->_parse_package_file };
  
  foreach my $method (@{$documentation{methods}}) {
    my $new_method = EnsEMBL::eDoc::Method->new((
                       name           => $method->{name},
                       documentation  => $method->{comment},
                       type           => $method->{type},
                       result         => $method->{return},
                       module         => $self
                     ));
    $self->add_method($new_method);
  }
  if ($documentation{isa}) {
    my @superclasses = @{$documentation{isa}};
    foreach my $class (@superclasses) {
      $self->add_superclass($class);
    }
  }

  if ($documentation{overview}) {
     $self->overview($documentation{overview});
  }

}

sub add_method {
  ### Adds a method name to the method array.
  my ($self, $method) = @_;
  push @{ $self->methods }, $method;
}

sub coverage {
  ### Calculates and returns the documentation coverage for all callable methods in a module. 
  my $self = shift;
  my $count = 0;
  my $total = 0;
  my $coverage;
  foreach my $method (@{ $self->methods }) {
    $total++;
    if ($method->type ne 'undocumented') {
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

sub _parse_package_file {
  ### Opens and parses Perl package files for methods and comments
  ### in e! doc format.
  my $self = shift;
  my %docs = ('methods' => []);
  open (my $fh, $self->location);

  my $lines = 0;
  my $subs = {};
  my $sub_name;
  my @order = ();
  my $params = 0;

  while (<$fh>) {
    $lines++;
    next unless $_;

    ## Get parent(s)
    if (/\@ISA/ || /^use [base|parent] qw\(([a-zA-Z:\s]+)\);/) {
      if (/\@ISA/) {
        my ($nothing, $isa) = split /=/;
        if ($isa) {
          $isa =~ s/qw|\(|\)|;//g;
          chomp $isa;
          $isa =~ s/\s+//g;
          $docs{isa} = [$isa];
        }
      }
      else {
        my @isa = split(/\s+/, $1);
        $docs{isa} = \@isa;
      }
      next;
    }

    ## Get overview
    unless (keys %$subs) {  
      if (/^#{2,3} /) {
        (my $line = $_) =~ s/^##(#)? //;
        $docs{overview} .= "$line<br />";
      }
    }

    ## Get method documentation
    if (/^sub (\w+) {/) {
      $sub_name = $1;
      $params = 0;
      $subs->{$sub_name} = {'name' => $sub_name, 'type' => 'undocumented'};
      push @order, $sub_name;
    }
    elsif (/^}/) {
      $sub_name = '';
    }

    if ($sub_name) {
      ### Keyword type
      if (/###([a-z]) /) {
        $subs->{$sub_name}{type} = $self->keywords->{$1};
      }
      ## "Normal" inline documentation
      elsif (/^\s+## (.+)/) {
        $subs->{$sub_name}{type} = 'miscellaneous';
        my $comment = $1;
        if ($comment =~ /^\@param/) {
          $params++;
          $comment =~ s/\@param/Arg[$params]:/;
        }
        elsif ($comment =~ / - /) {
          $comment = '&nbsp;&nbsp;&nbsp;&nbsp;'.$comment;
        }
        $subs->{$sub_name}{comment} .= "$comment<br />";
      }
      elsif (/SUPER::/) {
        if (/->(.*)::(.*)\(/) {
          $subs->{$sub_name}{super} = $2;
        } elsif (/->(.*)::(.*)\s+;/) {
          $subs->{$sub_name}{super} = $2;
        }
      }
    }
  }
  
  ## Now add the methods in the same order as the document (we can always sort by name later)
  foreach (@order) {
    push @{$docs{methods}}, $subs->{$_};
  }

  $self->lines($lines);
  return \%docs;
}

1;
