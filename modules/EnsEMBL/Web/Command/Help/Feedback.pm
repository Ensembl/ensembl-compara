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

package EnsEMBL::Web::Command::Help::Feedback;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub = $self->hub;
  my $help;

  my $module = 'EnsEMBL::Web::Data::'.$hub->param('type');
  if ($self->dynamic_use($module)) {
    $help = $module->new($hub->param('record_id'));
    foreach my $p ($hub->param) {
      next unless $p =~ /help_feedback/;
      if ($hub->param($p) eq 'yes') {
        $help->helpful($help->helpful + 1);
      }
      elsif ($hub->param($p) eq 'no') {
        $help->not_helpful($help->not_helpful + 1);
      }
    }
  }
  $help->save;

  my $param_hash = {'feedback' => $hub->param('record_id') };
  $self->ajax_redirect($hub->param('return_url'), $param_hash);
}

1;
