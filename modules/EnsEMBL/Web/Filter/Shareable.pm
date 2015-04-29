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

package EnsEMBL::Web::Filter::Shareable;

use strict;

use base qw(EnsEMBL::Web::Filter);

### Checks if user has any shareable data

sub init {
  my $self = shift;
  
  $self->messages = {
    no_group      => 'Could not find this group. Please try again',
    none          => 'You have no shareable data. Please add some data to your account in order to share it with colleagues or collaborators.',
    shared        => 'The selected record(s) are already shared with this group.',
    not_shareable => 'Some of the selected records could not be shared with the group, as they have not been saved to your user account. Please correct this and try again.'
  };
}

sub catch {
  my $self = shift;
  my $hub  = $self->hub;
  my $user = $hub->user;
  
  $self->redirect = '/UserData/SelectFile';
  
  my @temp_uploads = $hub->session->get_data(type => 'upload');
  my @user_uploads = $user ? $user->uploads : ();

  my @temp_urls = $hub->session->get_data(type => 'url');
  my @user_urls = $user ? $user->urls : ();

  $self->error_code = 'none' unless @temp_uploads || @user_uploads ||
                                    @temp_urls || @user_urls;

}

1;
