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

package EnsEMBL::Web::ZMenu::Idhistory::Label;

use strict;

use base qw(EnsEMBL::Web::ZMenu::Idhistory);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $id   = $hub->param('label') || die 'No label value in params';
  my $type = ucfirst $hub->param('feat_type');
  my $url;

  if ($type eq 'Gene') {    
    $url = $hub->url({
      type    => 'Gene',
      action  => 'Idhistory',
      r       => undef,
      g       => $id,
      t       => undef,
      p       => undef,
      protein => undef,
    });
  } elsif ($type eq 'Transcript'){    
    $url = $hub->url({
      type    => 'Transcript',
      action  => 'Idhistory',
      r       => undef,
      g       => undef,
      t       => $id,
      p       => undef,
      protein => undef,
    });
  } else {
    $url = $hub->url({
      type    => 'Transcript',
      action  => 'Idhistory/Protein',
      r       => undef,
      g       => undef,
      t       => undef,
      protein => $id
    });
  }

  $self->add_entry({
    label_html => $id,
    link       => $url
  });
}

1;
