=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Controller::Download;

use strict;
use warnings;

use Apache2::RequestUtil;
use EnsEMBL::Web::Hub;

use parent qw(EnsEMBL::Web::Controller);

sub new {
  my $class     = shift;
  my $r         = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $args      = shift || {};
  my $self      = bless {}, $class;

  my $json;

  my $hub = EnsEMBL::Web::Hub->new({
    apache_handle  => $r,
    session_cookie => $args->{'session_cookie'},
    user_cookie    => $args->{'user_cookie'},
  });

  my $object = $self->new_object($hub->type, {}, {'_hub' => $hub});

  if ($object && $object->can('handle_download')) {
    $object->handle_download($r);
  } else {
    print "Invalid download request\n";
  }

  return $self;
}

1;
