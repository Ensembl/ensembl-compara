# $Id$

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
    none_found => 'No sources found on server.',
    no_coords  => 'Source has no coordinate systems and none were selected'
  };
}

sub catch {
  my $self = shift;
  my $sources = $self->object->get_das_sources(@_);
  
  # Process any errors
  if (!ref $sources) {
    # Store the server's message in the session
    $self->hub->session->add_data(
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
