# $Id$

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
