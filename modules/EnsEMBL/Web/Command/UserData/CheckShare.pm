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
      $url_params->{'type'}        = $hub->param('type');
    } else {
      $url_params->{'action'}        = 'SelectShare';
      $url_params->{'filter_module'} = 'Shareable';
      $url_params->{'filter_code'}   = 'shared';
    }
  } else { ## Share via URL
    my @shares;
    
    foreach my $code (@share_ids) {
      if ($code !~ /^d+$/) {
        my $data = $session->get_data(type => 'upload', code => $code);
        
        if ($data->{'filename'}) {
          my $ref = $object->store_data(type => 'upload', code => $code);
        
          if ($ref) {
            push @shares, $ref;
          } else {
            $url_params->{'filter_module'} = 'Data';
            $url_params->{'filter_code'}   = 'no_save';
          }
        }
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
