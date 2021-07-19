=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Renderer::String;

use strict;

use IO::String;

use base qw(EnsEMBL::Web::Document::Renderer);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(string => '', @_);
  return $self;
}

sub printf  { shift->{'string'} .= sprintf shift, @_; }
sub print   { shift->{'string'} .= join '', @_; }
sub content { return $_[0]{'string'}; }

sub fh {
  my $self = shift;
  $self->{'fh'} = IO::String->new($self->{'string'}) unless $self->{'fh'};
  return $self->{'fh'};
}

1;