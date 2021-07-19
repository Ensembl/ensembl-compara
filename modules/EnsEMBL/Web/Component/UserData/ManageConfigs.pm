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

package EnsEMBL::Web::Component::UserData::ManageConfigs;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Component);

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my @configs = map $_->get_records_data({'type' => 'saved_config'}), grep $_, $hub->session, $hub->user;

  my $table   = $self->new_table([
    { key => 'id',    title => 'Link id',         width => '20%',   align => 'left',    sort => 'html', 'hidden' => 1 },
    { key => 'name',  title => 'Name',            width => '15%',   align => 'left',    sort => 'html' },
    { key => 'desc',  title => 'Description',     width => '30%',   align => 'left',    sort => 'html' },
    { key => 'compo', title => 'Page Component',  width => '15%',   align => 'left',    sort => 'html' },
    { key => 'icons', title => '',                width => '20%',   align => 'left' },
  ], [
    map {
      'id'    => $_->{'code'},
      'name'  => $_->{'name'},
      'desc'  => sprintf('<div class="desc%s">%s</div><span class="edit"></span>', $_->{'desc'} ? '' : ' empty', $_->{'desc'} || '<i>No description available</i></div>'),
      'compo' => $_->{'view_config_code'} =~ s/^.+\:\://r =~ s/([^A-Z]+)([A-Z]+)/$1 $2/rg,
      'icons' => sprintf(q(
        <input type="hidden" name="saved_config_code" value="%s" />
        <input type="hidden" name="saved_config_account" value="%s" />
        <input type="hidden" name="saved_config_name" value="%s" />
        <span class="save"></span><span class="delete"></span><span class="share"></span>
      ),
        $_->{'code'},
        $_->{'record_type'} eq 'user' ? 1 : '',
        $_->{'name'} =~ s/\W+/_/gr
      )
    }, @configs
  ], {'data_table' => 1, 'class' => 'manage-configs _manage_configs'}); # remove export & hide id by default

  return sprintf('<div>%s</div>
    <input type="hidden" class="panel_type" value="ManageConfigs" />
    <input type="hidden" class="js_param" name="move_config_url" value="%s" />
    <input type="hidden" class="js_param" name="delete_config_url" value="%s" />
    <input type="hidden" class="js_param" name="save_desc_url" value="%s" />',
    $table->render,
    $hub->url('Config', {'function' => 'move_config'}),
    $hub->url('Config', {'function' => 'delete_config'}),
    $hub->url('Config', {'function' => 'save_desc'}),
  );
}

1;
