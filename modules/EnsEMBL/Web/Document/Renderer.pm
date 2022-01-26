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

package EnsEMBL::Web::Document::Renderer;

use strict;
use Apache2::RequestUtil;

sub new {
  my $class = shift;

  my $self = {
    r     => undef,
    cache => undef,
    @_,
  };

  bless $self, $class;
  $self->r ||= Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  
  return $self;
}

sub r       :lvalue { $_[0]->{r} }
sub cache   :lvalue { $_[0]->{cache} }
sub session :lvalue { $_[0]->{session} }

sub valid   {1}
sub fh      {}
sub printf  {}
sub print   {}
sub close   {}
sub content {}
sub value   { shift->content }

1;