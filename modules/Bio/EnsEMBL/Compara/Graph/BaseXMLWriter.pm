=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::Graph::BaseXMLWriter;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Graph::BaseXMLWriter

=head1 DESCRIPTION

Used as a base for 

=head1 SUBROUTINES/METHODS

See inline

=head1 REQUIREMENTS

=over 8

=item L<XML::Writer>

=item L<IO::File> - part of Perl 5.8+

=back


=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

use strict;
use warnings;

use IO::File;
use XML::Writer;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

=pod

=head2 new()

  Arg[HANDLE] : IO::Handle; pass in an instance of IO::File or
                an instance of IO::String so long as it behaves
                the same as IO::Handle. Can be left blank in 
                favour of the -FILE parameter
  Arg[FILE]   : Scalar; location of the file to write to                        
  Description : Creates a new writer object. 
  Returntype  : Instance of the writer
  Exceptions  : None
  Status      : Internal  

=cut

sub new {
  my ($class, @args) = @_;
  my ($handle, $file) = rearrange([qw(handle file)], @args);

  my $self = bless({}, ref($class) || $class);
  
  $self->handle($handle) if defined $handle;
  $self->file($file) if defined $file;
  
  return $self;
}

=pod

=head2 handle()

  Arg[0] : The handle to set
  Description : Mutator for the handle backing this writer. If invoked without
  giving it an instance of a handler it will use the FILE attribute to open
  an instance of L<IO::File>
  Returntype : IO::Handle
  Exceptions : Thrown if we cannot open a file handle
  Status     : Stable

=cut

sub handle {
  my ($self, $handle) = @_;
  if(defined $handle) {
    $self->{_writer} = undef;
    $self->{handle} = $handle;
  }
  else {
    if((! defined $self->{handle}) && $self->file()) {
      $self->{handle} = IO::File->new($self->file(), 'w')
                        or die "Could not open file ".$self->file()." for writing: $!\n";
    }
  }
  return $self->{handle};
}

=pod

=head2 file()

  Arg[0] : Set the file location
  Description : Sets the file location to write to. Will undefine handle
  Returntype : String
  Exceptions : None
  Status     : Stable

=cut

sub file {
  my ($self, $file) = @_;
  if(defined $file) {
    $self->{handle} = undef;
    $self->{_writer} = undef;
    $self->{file} = $file;
  }
  return $self->{file};
}

=pod

=head2 finish()

  Description : An important method which will write the final element. This
  allows you to stream any number of trees into one XML file and then call
  finish once you are done with it. B<Always call this method when you are
  done otherwise your XML will not be valid>.
  Returntype : Nothing
  Exceptions : Thrown if you are not finishing the file off with the correct
  end element
  Status     : Stable

=cut

sub finish {
  my ($self) = @_;
  $self->_write_closing();
  return;
}

=pod

=head2 namespaces()

Alter to return the namespaces to use in this XML file. If specifed
the usage of XSI will be implicit and will mean the 2001 W3C schema. Return
type should be a HashRef keyed by the URI and value should be the prefix
to use. Use an empty prefix to set the namespace as default

=cut

sub namespaces {
  my ($self) = @_;
  return {};
}

=pod

=head2 xml_schema_namespace()

Returns the namespace of the XML schema (currently W3C 2001)

=cut

sub xml_schema_namespace {
  my ($self) = @_;
  my $xsi_uri = 'http://www.w3.org/2001/XMLSchema-instance';
  return $xsi_uri;
}

=pod

=head2 _writer()

Used to get the writer instance to use

=cut

sub _writer {
  my ($self) = @_;
  if(!$self->{_writer}) {
    my $writer = $self->_build_writer();
    $self->{_writer} = $writer;
    $self->_write_opening($writer);
  }
  return $self->{_writer};
}

=pod

=head2 _build_writer()

Builds the XML::Writer instance taking into account the handle to use and the
namespaces to register. Override to provide a custom writer instance

=cut

sub _build_writer {
  my ($self) = @_;
  my %namespaces = %{$self->namespaces()};
  my %args = (
    OUTPUT => $self->handle(), 
    DATA_MODE => 1, 
    DATA_INDENT => 2
  );
  if(scalar(keys %namespaces)) {
    $namespaces{$self->xml_schema_namespace()} = 'xsi';
    $args{NAMESPACES} = 1;
    $args{PREFIX_MAP} = \%namespaces;
  }
  return XML::Writer->new(%args);
}

=pod 

=head2 _write_opening()

Override to write the starting tag along with namespaces if required. Method
takes the writer instance as its first agument (since this is called before
the writer instance is pushed into $self).

=cut

sub _write_opening {
  my ($self, $w) = @_;
  throw 'Unimplemented';
}

=pod 

=head2 _write_closing()

Override to write the ending tag along. The writer instance has now been
pushed into $self.

=cut

sub _write_closing {
  my ($self) = @_;
  throw 'Unimplemented';
}

1;
