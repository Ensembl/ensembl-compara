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

package EnsEMBL::Web::Filter::Data;

use strict;

use base qw(EnsEMBL::Web::Filter);

### Checks if an uploaded file or other input is non-zero and usable

sub init {
  my $self = shift;
  
  $self->messages = {
    no_url            => 'No URL was entered. Please try again.',
    no_response       => 'We were unable to access your data file. If you continue to get this message, there may be an network issue, or your file may be too large for us to upload.',
    invalid_mime_type => 'Your file does not appear to be in a valid format. Please try again.',
    empty             => 'Your file appears to be empty. Please check that it contains correctly-formatted data.',
    too_big           => 'Your file is too big to upload. Please select a smaller file.',
    no_save           => 'Your data could not be saved. Please check the file contents and try again.'
  };
}

1;
