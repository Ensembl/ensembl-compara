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

package EnsEMBL::Selenium::Test::SpeciesPages;

### Parent for modules that test species-specific pages (e.g. Gene) 

use strict;

use parent 'EnsEMBL::Selenium::Test';

sub new {
  my ($class, %args) = @_;

  ## Check we have a species before proceeding
  return ['bug', "These tests require a species", $class, 'new'] unless $args{'species'};

  my $self = $class->SUPER::new(%args);
  return $self;
}

sub test_lh_menu {
### Tests all links on lefthand menu of a given page type (e.g. Gene)
  my $self    = shift;
  my $sel     = $self->sel;
  my $current = $self->get_current_url();

  my ($goto, $error) = $self->default_url;
  return ($goto, $error) if $error;

  $self->no_mirrors_redirect;

  my $error = eval { $sel->open($goto); };
  if ($error && $error ne 'OK') {
    return ['fail', "Couldn't open sample page $goto to check navigation links", ref($self), 'test_lh_menu'];
  }

  my @responses;
  my $load_error = $sel->ensembl_wait_for_page_to_load;
  if ($load_error && ref($load_error) eq 'ARRAY' && $load_error->[0] eq 'fail') {
    push @responses, $load_error;
  }
  else {
    push @responses, ($sel->ensembl_click_all_links('.local_context'));
  }
  return @responses;
}

1;
