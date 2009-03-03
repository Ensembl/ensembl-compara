package EnsEMBL::Web::Filter::Data;

use strict;
use warnings;
use Class::Std;

use base qw(EnsEMBL::Web::Filter);

### Checks if an uploaded file or other input is non-zero and usable

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({
    'no_file' => 'No data was uploaded. Please try again.',
    'no_url'  => 'No URL was entered. Please try again.',
    'empty'   => 'Your file appears to be empty. Please check that it contains correctly-formatted data.',
    'no_save' => 'Your data could not be saved. Please check the file contents and try again.',
  });
}

sub catch {
  my $self = shift;
}

}

1;
