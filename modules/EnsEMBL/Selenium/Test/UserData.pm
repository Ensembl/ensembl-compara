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
  my $self          = shift;
  my $sel           = $self->sel;
  my $species       = $self->species;

  $self->no_mirrors_redirect;

  my @responses;

  my $species_name = $species->{'name'};
  my $files        = $species->{'files'} || {};

  my $home_page = sprintf('%s/Info/Index', $species_name);
  my $error = eval { $self->sel->open($home_page); };
  if ($error && $error ne 'OK') {
    return ['fail', "Couldn't open $species_name home page", ref($self), 'test_lh_menu'];
  }
  else { 
    $error = $sel->ensembl_wait_for_page_to_load;
    if ($error && $error ne 'OK') {
      push @responses, $error;
    }
    else {
      ## Check we're on the right page!
      my $error = $sel->ensembl_is_text_present('Genome assembly: '.$species->{'assembly_name'});
      if ($error) {
        push @responses, $error;
      }
      else {
        my $upload_text = 'Display your data in Ensembl';
        while (my($format, $file_url) = each(%$files)) {
          $error = $sel->ensembl_click("link=$upload_text"); 
          if ($error && $error ne 'OK') {
            push @responses, $error;
          }
          else {
            $error = $sel->ensembl_wait_for_ajax(undef,10000);
            push @responses, $error;
            push @responses, $self->_upload_file($format, $file_url);
          }
        }
      }
    }
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
  push @responses, $sel->ensembl_is_text_present('Add a custom track');
 
  ## Interact with form
  my $form = "//div[\@id='SelectFile']/form";

  ## Type file name into textarea
  my $textarea = "$form/fieldset/div[4]/div[1]/textarea";
  push @responses, $sel->ensembl_type($textarea, $url);

  ## Select the format
  my $dropdown = "$form/fieldset/div[5]/div[1]/select";
  push @responses, $sel->ensembl_type($dropdown, $format);

  ## Submit the form
  push @responses, $sel->ensembl_submit("xpath=$form");

  return @responses;
}

1;
