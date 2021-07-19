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

package EnsEMBL::Web::Document::Element::TmpMessage;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents);

use parent qw(EnsEMBL::Web::Document::Element);

sub init {
  my $self  = shift;
  my $hub   = $self->hub;
  my $file  = $hub->species_defs->ENSEMBL_TMP_MESSAGE_FILE;
  my %file;

  if (-e $file && -r $file) {
    %file = file_get_contents($file, sub { chomp; return $_ =~ /^#|^\s*$/ ? () : split(/\s+/, $_, 2) });
  }

  $self->{'file'} = \%file;
}

sub content {
  my $self = shift;

  my $popup_message = $self->{'file'}{'message'} ? $self->dom->create_element('div', {
    'id'        => 'tmp_message',
    'children'  => [{
      'node_name'   => 'div',
      'inner_HTML'  => encode_entities($self->{'file'}{'message'})
    }, {
      'node_name'   => 'input',
      'type'        => 'hidden',
      'name'        => 'md5',
      'value'       => md5_hex($self->{'file'}{'message'})
    }, {
      'node_name'   => 'input',
      'type'        => 'hidden',
      'name'        => 'expiry',
      'value'       => $self->{'file'}{'cookieExpiryHours'} || 24
    }, {
      'node_name'   => 'input',
      'type'        => 'hidden',
      'name'        => 'colour',
      'value'       => $self->{'file'}{'colour'} || 'warning'
    }, {
      'node_name'   => 'input',
      'type'        => 'hidden',
      'name'        => 'position',
      'value'       => $self->{'file'}{'position'} || ''
    }]
  })->render : '';

  my $announcement_banner_message = $self->{'file'}{'banner_message'} ? $self->dom->create_element('div', {
    'id'          => 'announcement-banner',
    'inner_HTML'  => $self->{'file'}{'banner_message'}
  })->render : '';


  return {
    'popup_message' => $popup_message,
    'announcement_banner_message' => $announcement_banner_message 
  }


}

1;
