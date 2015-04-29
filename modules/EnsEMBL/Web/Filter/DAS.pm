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

package EnsEMBL::Web::Filter::DAS;

use strict;

use base qw(EnsEMBL::Web::Filter);

### Checks if a DAS server is returning sources

sub init {
  my $self = shift;
  
  # Set the messages hash here (DAS message is a fallback in case the server message stored in the session is lost)
  $self->messages = {
    no_server  => 'No server was selected.',
    DAS        => 'The DAS server returned an error.',
    none_found => 'No sources found/selected on server.',
    no_coords  => 'Source has no coordinate systems and none were selected'
  };
}

sub catch {
  my $self = shift;
  my $sources = $self->object->get_das_sources(@_);
  
  # Process any errors
  if (!ref $sources) {
    # Store the server's message in the session
    $self->object->hub->session->add_data(
      type     => 'message',
      code     => 'DAS_server_error',
      message  => "Unable to access DAS source. Server response: $sources",
      function => '_error'
    );
    
    return undef;
  } elsif (!scalar @$sources) {
    $self->error_code = 'none_found';
    return undef;
  }
  
  return $sources;
}

1;
