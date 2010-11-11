# $Id$

package EnsEMBL::Web::Command::UserData::SaveRemote;

use strict;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $url     = $hub->species_path($hub->data_species) . '/UserData/';
  my $user    = $hub->user;
  my $session = $hub->session;
  my @sources = grep $_, $hub->param('dsn');
  my ($node, $param);

  if ($user && scalar @sources) {
    my $all_das = $session->get_all_das;
    
    foreach my $logic_name  (@sources) {
      my $das    = $all_das->{$logic_name} || warn "*** $logic_name";
      my $result = $user->add_das($das);
      
      if ($result) {
        $node = 'ManageData';
      } else {
        $node = 'ShowRemote';
        $param->{'filter_module'} = 'UserData';
        $param->{'filter_code'}   = 'no_das';
      }
    }
    
    # Just need to save the session to remove the source - it knows it has changed
    $session->save_das;
  }

  ## Save any URL data
  if (my @codes = $hub->param('code')) {
    my $error = 0;
    
    foreach my $code (@codes) {
      next unless $code;
      
      if (my $url = $session->get_data(type => 'url', code => $code)){
        if ($user->add_to_urls($url)) {
          $session->purge_data(type => 'url', code => $code);
        } else {
          warn "failed to save url: $code";
          $error = 1;
        }
      } elsif (my $bam = $session->get_data(type => 'bam', code => $code)) {
        my $added = $user->add_to_bams($bam);
        if ($added) {
          $session->purge_data(type => 'bam', code => $code);
        } else {
          warn "failed to save bam: $code";
          $error = 1;
        }
      }
    }
    
    if ($error) {
      $node = 'ShowRemote';
      $param->{'filter_module'} = 'UserData';
      $param->{'filter_code'}   = 'no_url';
    } else {
      $node = 'ManageData';
    }
  }
  
  $url .= $node;
  
  $self->ajax_redirect($url, $param); 
}

1;
