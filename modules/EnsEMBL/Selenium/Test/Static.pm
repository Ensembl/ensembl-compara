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
  $sel->open_ok("/");  

  $sel->ensembl_wait_for_page_to_load
  and $sel->ensembl_is_text_present("Ensembl release $this_release")
  and $sel->ensembl_is_text_present("What's New in Release $this_release")
  and $sel->ensembl_is_text_present('Did you know')
  and $sel->ensembl_click_links(["link=View full list of all Ensembl species"]);
 
  $sel->go_back();
  $sel->ensembl_wait_for_page_to_load;
  $sel->ensembl_click_links(["link=acknowledgements page"]); 

  $sel->go_back()
  and $sel->ensembl_wait_for_page_to_load;  
  
  $sel->ensembl_click_links(["link=About Ensembl"]); 
  
  $sel->go_back()
  and $sel->ensembl_wait_for_page_to_load;
  
  $sel->ensembl_click_links(["link=Privacy Policy"]);
}

sub test_debug {
### Quick'n'dirty test to ensure that the test script is working!
  my $self = shift;
  return ('pass', 'DEBUG OK!');
}


1;
