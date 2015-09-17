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

package EnsEMBL::Selenium::Test::UserData;

### Tests for user data interface

use strict;

use parent 'EnsEMBL::Selenium::Test';

sub test_upload_file {
  my ($self, $args) = @_;
  my $sel           = $self->sel;
  my $species       = $self->species;
  my $upload_text   = 'Display your data in Ensembl';

  $self->no_mirrors_redirect;

  my @responses;

  my $species_name = $species->{'name'};

  my $home_page = sprintf('%s/Info/Index', $species_name);
  my $error = eval { $self->sel->open($homepage); };
  if ($error && $error ne 'OK') {
    return ['fail', "Couldn't open $species_name home page", ref($self), 'test_lh_menu'];
  }
  else { 
    $error = $sel->ensembl_wait_for_page_to_load;
    if ($error && $error->[0] eq 'fail') {
      push @responses, $error;
    }
    else {
      $error = $sel->ensembl_click_links(["link=$upload_text"]); 
      push @responses, $error;
    }
  }
  return @responses;
}

1;
