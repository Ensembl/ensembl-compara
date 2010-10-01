# $Id$

package EnsEMBL::Web::Command::UserData::CheckShare;

use strict;

use EnsEMBL::Web::Data::Group;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $session = $hub->session;
  my $url     = $hub->species_path($hub->data_species) . '/UserData/';
  my $param;

  if (my $group_id = $hub->param('webgroup_id')) { ## Share with group
    ## Check if it is already shared
    my @ids = ($hub->param('share_id'));
    my @shareables;

    my $group = EnsEMBL::Web::Data::Group->new($group_id);
    my @group_records = $group->records;

    foreach my $id (@ids) {
      next unless $id;
      my $shared = grep { $id == $_->cloned_from } $group->records;
      push @shareables, $id unless $shared;
    }
    
    if (@shareables) {
      $url .= 'ShareRecord';
      $param->{'webgroup_id'} = $group_id;
      $param->{'id'}          = \@shareables;
      $param->{'type'}        = $hub->param('type');
    } else {
      $url .= 'SelectShare';
      unless ($param->{'filter_module'}) {
        $param->{'filter_module'} = 'Shareable';
        $param->{'filter_code'} = 'shared';
      }
    }
  }
  else { ## Share via URL
    my @shares = ($hub->param('share_id'));
    foreach my $code (@shares) {
      if ($code !~ /^d+$/) {
        my $data = $session->get_data(type => 'upload', code => $code);
        
        if ($data->{'filename'}) {
          if (my $ref = $object->store_data(type => 'upload', code => $code)) {
            @shares = grep {$_ ne $code} @shares;
            push @shares, $ref;
          } else {
            $param->{'filter_module'} = 'Data';
            $param->{'filter_code'} = 'no_save';
          }
        }
      }
    }
    
    if (@shares) {
      $url .= 'ShareURL';
      $param->{'share_id'} = \@shares;
    } else {
      $url .= 'SelectShare';
    }
  }

  $self->ajax_redirect($url, $param);
}

1;
