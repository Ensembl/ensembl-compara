# $Id$

package EnsEMBL::Web::Command::UserData::CheckShare;

use strict;

use EnsEMBL::Web::Data::Group;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self       = shift;
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $session    = $hub->session;
  my $group_id   = $hub->param('webgroup_id');
  my @share_ids  = $hub->param('share_id');
  my $url_params = { __clear => 1 };
  my $param;
  
  if ($group_id) { ## Share with group
    ## Check if it is already shared
    my $group         = new EnsEMBL::Web::Data::Group($group_id);
    my %group_records = map { $_->cloned_from => 1 } $group->records;
    my @shareables    = map { $_ && $group_records{$_} ? () : $_ } @share_ids;
    
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
    my @shares = grep /^\d+$/, @share_ids; # user data being shared
    
    foreach (grep !/^\d+$/, @share_ids) { # session data being shared
      my $data = $session->get_data(type => 'upload', code => $_);
      
      if ($data) {
        if ($data->{'analyses'}) {
          push @shares, $_;
        } else {
          my $ref = $object->store_data(share => 1, type => $data->{'type'}, code => $_);
          
          if ($ref) {
            push @shares, $ref;
            $url_params->{'reload'} = 1;
          } else {
            $url_params->{'filter_module'} = 'Data';
            $url_params->{'filter_code'}   = 'no_save';
          }
        }
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
  
  $self->ajax_redirect($hub->url($url_params));
}

1;
