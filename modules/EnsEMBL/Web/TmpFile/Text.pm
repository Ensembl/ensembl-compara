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

package EnsEMBL::Web::TmpFile::Text;

## EnsEMBL::Web::TmpFile::Text - module for dealing with temporary text files
## see base module for more information

use strict;
use Compress::Zlib qw(gzopen $gzerrno);
use Archive::Zip;

use base 'EnsEMBL::Web::TmpFile';

## Accessor for the filename for just uploaded file
__PACKAGE__->mk_accessors('tmp_filename');

sub new {
  my $class = shift;
  my %args  = @_;

  my $self = $class->SUPER::new(
    tmp_filename => undef,         ## for user uploaded files
    prefix       => 'user_upload',
    drivers      => EnsEMBL::Web::TmpFile::Driver::Disk->new,
    %args,
  );
 
  if ($args{filename}) {
    $args{filename} =~ /((\.[a-zA-Z0-9]{1,4}){1,2})$/;
    $self->{extension} = $1;
  }
  else {
    $self->{extension} = 'txt';
  }
  
  if ($args{tmp_filename}) {
    if ($self->{extension} =~ /gz$/) {
      my $content = '';
      my $file = $args{tmp_filename};
      my $gz = gzopen( $file, 'rb' )
         or warn "GZ Cannot open $file: $gzerrno\n";
      if ($gz) {
        my $buffer  = 0;
        $content   .= $buffer while $gz->gzread( $buffer ) > 0;
        $gz->gzclose;
      }
      $self->{content} = $content;
    }
    elsif ($self->{extension} =~ /zip$/) {
      my $content = '';
      my $file = $args{tmp_filename};
      my $zip = Archive::Zip->new();
      my $error = $zip->read($file);
      unless ($error) { ## no error code returned
        foreach my $member ($zip->members) {
          $content .= $zip->contents($member);
        }
      }
      $self->{content} = $content;
    }
    else {
      open TMP_FILE, $args{tmp_filename};
      local $/;
      $self->{content} = do {local $/; <TMP_FILE> };
      close TMP_FILE;
    }
    unlink $args{tmp_filename};
  }

  return $self;
}

1;
