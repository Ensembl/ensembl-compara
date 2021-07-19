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

package EnsEMBL::Selenium::Test::UserData;

### Tests for user data interface

use strict;

use parent 'EnsEMBL::Selenium::Test';

sub test_upload_file {
  my $self          = shift;
  my $sel           = $self->sel;
  my $species       = $self->species;

  $self->no_mirrors_redirect;

  ## Go to the species homepage
  my $species_name = $species->{'name'};
  my $home_page = sprintf('%s/Info/Index', $species_name);

  my $result = $sel->ensembl_open($home_page);
  return $result if $self->test_fails($result);

  $result = $sel->ensembl_wait_for_page_to_load;
  return $result if $self->test_fails($result);

  ## Check we're on the right page!
  $result = $sel->ensembl_is_text_present('Genome assembly: '.$species->{'assembly_name'});
  return $result if $self->test_fails($result);

  ## Loop through the test files in the species configuration, opening 
  ## the interface for each one and attempting an upload
  my $files       = $species->{'files'} || {};
  my $upload_text = 'Display your data in Ensembl';
  my @responses;

  while (my($format, $file_url) = each(%$files)) {
    $result = $sel->ensembl_click($upload_text); 
    push @responses, $result;
    next if $self->test_fails($result);

    $result = $sel->ensembl_wait_for_ajax(undef,10000);
    push @responses, $result;
    next if $self->test_fails($result);

    push @responses, $self->_upload_file($format, $file_url);
    $sel->go_back();
  }
  return @responses;
}

sub _upload_file {
### Attempt to upload a file from a URL
### @param $format String - format of the test file
### @param $url String - URL of the test file
  my ($self, $format, $url) = @_;
  my $sel = $self->sel;
  my @responses;

  ## Sanity check - have we opened the form?
  my $result = $sel->ensembl_is_text_present('Add a custom track');
  push @responses, $result;
  return $result if $self->test_fails($result);
 
  ## Interact with form
  my $form = "//form[\@id='select']";

  ## Type file name into textarea
  my $textarea = "$form/fieldset/div[4]/div/textarea";
  $result = $sel->ensembl_type("xpath=$textarea", $url);
  push @responses, $result;
  return @responses if $self->test_fails($result);

  ## Select the format - N.B. field is unhidden by JavaScript
  my $dropdown = "$form/fieldset/div[5]/div/select";
  $result = $sel->ensembl_wait_for_element("xpath=$dropdown");
  push @responses, $result;
  return @responses if $self->test_fails($result);

  $result = $sel->ensembl_type("xpath=$dropdown", $format);
  push @responses, $result;
  return @responses if $self->test_fails($result);

  ## Submit the form
  push @responses, $sel->ensembl_submit("xpath=$form");
  return @responses;
}

1;
