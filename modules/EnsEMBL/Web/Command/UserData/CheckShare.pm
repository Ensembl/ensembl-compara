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

package EnsEMBL::Web::Command::UserData::CheckShare;

use strict;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self       = shift;
  my $hub        = $self->hub;
  my $user       = $hub->user;
  my $object     = $self->object;
  my $session    = $hub->session;
  my $group_id   = $hub->param('webgroup_id');
  my $group      = $user && $group_id ? $user->get_group($group_id) : undef;
  my @share_ids  = $_[0] ? @_ : $hub->param('share_id');
  my $url_params = { __clear => 1 };
  my $param;
  
  if ($group) { ## Share with group
    ## Check if it is already shared
    my %group_records = map { $_->cloned_from => 1 } $user->get_group_records($group);
    my @shareables    = grep { $_ && !$group_records{$_} } @share_ids;
    
    if (scalar @shareables) {
      $url_params->{'action'}      = 'ShareRecord';
      $url_params->{'webgroup_id'} = $group_id;
      $url_params->{'id'}          = \@shareables;
      $url_params->{'source'}      = $hub->param('source');
    } else {
      $url_params->{'action'}        = 'SelectShare';
      $url_params->{'filter_module'} = 'Shareable';
      $url_params->{'filter_code'}   = 'shared';
    }
  } else { ## Share via URL
    my @shares;
    
    foreach (@share_ids) {
      # user data being shared
      if (/^(\d+)-(\w+)$/) {
        push @shares, $_;
        next;
      }
      
      # session data being shared
      my $data = $session->get_data(type => 'upload', code => $_);
      
      if ($data) {
        push @shares, $_;
      } elsif ($session->get_data(type => 'url', code => $_)) {
        push @shares, $_;
      }
    }
    
    if (scalar @shares) {
      $url_params->{'action'}   = 'ShareURL';
      $url_params->{'share_id'} = \@shares;
    } else {
      $url_params->{'action'} = 'ShareRecord';
    }
  }
  
  return @{$url_params->{'share_id'} || $url_params->{'id'}} if $_[0];
  
  $self->ajax_redirect($hub->url($url_params));
}

1;
