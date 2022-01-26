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

package EnsEMBL::Web::TmpFile::Driver::Disk;

use strict;

use Compress::Zlib qw(gzopen $gzerrno);
use File::Path;
use File::Spec::Functions qw(splitpath);

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;

  return $self;
}

sub exists {
  my ($self, $obj) = @_;
  return -e $obj->full_path && -f $obj->full_path;
}

sub delete {
  my ($self, $obj) = @_;
  return unlink $obj->full_path;
}

sub get {
  my ($self, $obj) = @_;
  my $file = $obj->full_path;

  my $content = '';
  if (($obj->compress || $obj->extension =~ /gz$/) && !$obj->get_compressed) {
    my $gz = gzopen( $file, 'rb' )
         or warn "GZ Cannot open $file: $gzerrno\n";
    if ($gz) {
      my $buffer  = 0;
      $content   .= $buffer while $gz->gzread( $buffer ) > 0;
      $gz->gzclose;
    }
  } else {
    local $/ = undef;
    open FILE, $file;
    $content = <FILE>;
    close FILE;    
  }
  return $content;  
}

sub save {
  my ($self, $obj) = @_;
  my $file = $obj->full_path;

  $self->make_directory($file);

  eval {
    if ($obj->compress) {
      my $gz = gzopen($file, 'wb')
           or die "GZ Cannot open $file: $gzerrno\n";
      $gz->gzwrite($obj->content)
           or die "GZ Cannot write content: $gzerrno\n";
      $gz->gzclose();
    } else {
      open(FILE, ">$file")
        or die "Cannot open file $file: $!";
      binmode FILE;
      print FILE $obj->content;
      close FILE;
    }
  };

  if ($@) {
    warn $@;
    return undef;
  }
  
  return 1;
}

sub make_directory {
### Creates a writeable directory - making sure all parents exist!
  my ($self, $path) = @_;

  my ($volume, $dir_path, $file) = splitpath( $path );
  mkpath( $dir_path, 0, 0777 );
  return ($dir_path, $file);
}

1;
