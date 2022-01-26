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

package EnsEMBL::Web::Document::Renderer::File;

use strict;
use IO::File;
sub new {
  my $class = shift;
  my $filename = shift;
  my $fh = IO::File->new;
  my $self;
  if( $fh->open( ">$filename") ) {
    $self = { 'file' => $fh };
  } else {
    $self = { 'file' => undef };
  }
  bless $self, $class;
  return $self;
}

sub fh {
  my $self = shift;
  return $self->{'file'};
}

sub valid  { return $_[0]->{'file'}; }
sub printf { my $self = shift; my $FH = $self->{'file'}; printf $FH @_ if $FH; }
sub print  { my $self = shift; my $FH = $self->{'file'}; print  $FH @_ if $FH; }

sub close  { my $FH = $_[0]->{'file'}; close $FH; $_[0]->{'file'} = undef; }
sub DESTROY { my $FH = $_[0]->{'file'}; close $FH; }
1;
