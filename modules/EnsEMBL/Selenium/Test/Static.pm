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

package EnsEMBL::Selenium::Test::Static;

### Tests for static content

use strict;

use parent 'EnsEMBL::Selenium::Test';

sub test_homepage {
  my ($self, $links) = @_;
  my $sel           = $self->sel;
  my $this_release  = $self->conf('release');
  my $current = $self->get_current_url();  

  $self->no_mirrors_redirect;

  my $error = try { $sel->open("/"); }
                catch { return ['fail', "Couldn't open home page at ".$sel->{'browser_url'}]; };
  return $error if $error;

  my @responses; 

  ## Check main content
  my $load_error = $sel->ensembl_wait_for_page_to_load;
  if ($load_error && ref($load_error) eq 'ARRAY' && $load_error->[0] eq 'fail') {
    push @responses, $load_error;
  }
  else {
    push @responses, $sel->ensembl_is_text_present("Ensembl release $this_release");
    push @responses, $sel->ensembl_is_text_present("What's New");
    push @responses, $sel->ensembl_is_text_present('Did you know');
    push @responses, $sel->ensembl_click_links(["link=View full list of all Ensembl species"]);
  
    $sel->go_back();
  }
  
  ## Try links
  my @links = ('acknowledgements page', 'About Ensembl', 'Privacy Policy');
  foreach (@links) {
    $load_error = $sel->ensembl_wait_for_page_to_load;
    if ($load_error && $load_error->[0] eq 'fail') {
      push @responses, $load_error;
    }
    else {
      push @responses, $sel->ensembl_click_links(["link=$_"]); 
      $sel->go_back();
    }
  }
  return @responses;
}

1;
