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
  my $default_keywords = "a accessor c constructor d destructor x deprecated i initialiser";
  my $self = {
    'methods'     => $params{'methods'}     || [],
    'name'        => $params{'name'}        || '',
    'inheritance' => $params{'inheritance'} || [],
    'subclasses'  => $params{'subclasses'}  || [],
    'location'    => $params{'location'}    || '',
    'lines'       => $params{'lines'}       || '',
    'overview'    => $params{'overview'}    || '',
    'identifier'  => '#{2,3}',
    'keywords'    => $params{'keywords'}    || $default_keywords,
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
  
  foreach my $method (keys %{ $documentation{methods} }) {
    my $new_method = EnsEMBL::eDoc::Method->new((
                       name           => $method,
                       documentation  => $documentation{methods}{$method}->{comment},
                       type           => $documentation{methods}{$method}->{type},
                       result         => $documentation{methods}{$method}->{return},
                       module         => $self
                     ));
    if ($documentation{table}{$method}) {
      $new_method->table($documentation{table}{$method});
    }
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

    ## Get parent(s)
    if (/\@ISA/) {
      my ($nothing, $isa) = split /=/;
      if ($isa) {
        $isa =~ s/qw|\(|\)|;//g;
        chomp $isa;
        $isa =~ s/\s+//g;
        $docs{isa} = [$isa];
      }
    }
    elsif (/^use [base|parent] qw\(([a-zA-Z:\s]+)\);/) {
      my @isa = split(/\s+/, $1);
      $docs{isa} = \@isa;
    }

    ## Get package name and introductory documentation
    if (/^package/) {
      $package = $_;
      $docs{overview} = "";
    }

    if ($package && $sub eq "" && /^$comment_code /) {
      my $temp = $_;
      $temp =~ s/$comment_code//g;
      $docs{overview} .= $temp;
    }

    ## Get method documentation
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
      (my $comment = $_) =~ s/^$comment_code//;
      if ($comment) {
        $comment =~ s/^\s+|\s+$//g;
        chomp $comment;
        if ($comment eq "") {
          $comment .= "<br /><br />";
        }

        my @elements = split /\s+/, $comment;
        if (!$docs{methods}{$sub}{type}) {
          $docs{methods}{$sub}{type} = "miscellaneous";
        }
        if ($#elements == 0 and $comment ne '___') {
          $comment = ucfirst($self->convert_keyword($comment));
          $docs{methods}{$sub}{type} = lc($comment);
          $comment .= ". ";
        } else {
          if ($elements[0] && $elements[0] =~ /^.eturns/) {
            $docs{methods}{$sub}{return} = "@elements";
            $table = "";
            $block = 1;
          }
        }
        $docs{methods}{$sub}{comment} .= " " . $comment if !$block;
        $block = 0;
      }
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

1;
