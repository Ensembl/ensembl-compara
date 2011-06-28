# $Id$

package EnsEMBL::Web::Component::UserData::DasFeedback;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption { return 'Attached DAS sources'; }

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $form    = $self->new_form({ id => 'das_feedback', mehtod => 'post' });
  my $das     = $hub->session->get_all_das;
  my @added   = grep $_, $hub->param('added');
  my @skipped = grep $_, $hub->param('skipped');
  my @really_added;

  if (scalar @added) {
    foreach my $logic_name (@added) {
      my $source = $das->{$logic_name};
      
      if ($source) {
        push @really_added, $logic_name;
      } else {
        push @skipped, $logic_name;
      }
    }
  }
 
  if (scalar @really_added) {
    my $referer = $hub->referer;
    my %params  = (
      type   => $referer->{'ENSEMBL_TYPE'},
      action => $referer->{'ENSEMBL_ACTION'},
      map { $_ => $referer->{'params'}{$_}[0] } keys %{$referer->{'params'}}
    );
    
    my $url;
    
    $form->add_element(type => 'SubHeader', value => 'The following DAS sources have now been attached:');
    
    foreach my $logic_name (@really_added) {
      my $source = $das->{$logic_name};
      
      if (!$url) {
        foreach (@{$hub->components}) {
          if ($source->is_on("$referer->{'ENSEMBL_TYPE'}/$_")) {
            $url = $hub->url({%params, function => $logic_name });
            last;
          }
        }
      }
      
      $form->add_element(
        type    => 'Information',
        classes => [ 'no-bold' ],
        value   => sprintf(
          '<strong>%s</strong><br />%s<br /><a href="%s">%3$s</a>',
          $source->label,
          $source->description,
          $source->homepage
        )
      );
    }
    
    $form->add_element(type => 'ForceReload', url => $url);
  }
 
  if (scalar @skipped) {
    $form->add_element(type => 'SubHeader', value => 'The following DAS sources could not be attached:');
    
    foreach my $logic_name (@skipped) {
      my $source = $das->{$logic_name};
      
      if ($source) {
        $form->add_element(
          type    => 'Information',
          classes => [ 'no-bold' ],
          value   => sprintf(
            '<strong>%s</strong><br />%s<br /><a href="%s">%3$s</a>',
            $source->label,
            $source->description,
            $source->homepage
          )
        );
      } else {
        $form->add_element(type => 'Information', value => $logic_name);
      }
    }
  }
  
  return $form->render;
}

1;
