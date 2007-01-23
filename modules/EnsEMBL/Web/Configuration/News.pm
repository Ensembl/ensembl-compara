package EnsEMBL::Web::Configuration::News;

### Methods for configuring dynamic pages based on the News object

use strict;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Configuration;
#use EnsEMBL::Web::Wizard::News;

our @ISA = qw( EnsEMBL::Web::Configuration );

#-----------------------------------------------------------------------


sub newsview {
### Function to configure newsview

### This is a two-step view giving the user access to current or previous
### news items, by species, release, topic, etc.
  my $self   = shift;
  if (my $panel = $self->new_panel ('Image',
        'code'    => "info$self->{flag}",
        'object'  => $self->{object}) 
    ) {
    # this is a two-step view, so we need 2 separate sections
    if ($self->{object}->param('error') eq 'not_present') {
        $panel->{'caption'} = 'Not Present';
        $panel->add_components(qw(
                no_data     EnsEMBL::Web::Component::News::no_data
            ));
    }
    elsif ($self->{'object'}->param('submit') || $self->{'object'}->param('rel')) {
        # Step 2 - user has chosen a data range
        $panel->add_components(qw(show_news EnsEMBL::Web::Component::News::show_news));
    }
    else {
        # Step 1 - initial page display
        $panel->{'caption'} = 'Select News to View';
        $panel->add_components(qw(select_news EnsEMBL::Web::Component::News::select_news));
        $panel->add_form( $self->{page}, qw(select_news  EnsEMBL::Web::Component::News::select_news_form) );
    }
    $self->{page}->content->add_panel($panel);
  }
}

#-----------------------------------------------------------------------

sub context_menu {
### Context menu for newsview - provides links forwards and backwards by release
  my $self = shift;
  my $species  = $self->{object}->species;
  my $flag     = "";
  $self->{page}->menu->add_block( $flag, 'bulleted', "News Archive" );

  $self->{page}->menu->add_entry( $flag, 'text' => "Select news to view",
                                  'href' => "/$species/newsview" );
  ## link back to previous release
  my $release = $self->{object}->param('rel') || $self->{object}->param('release_id');
  if ($release eq 'current') {
    $release = $SiteDefs::VERSION;
  }
  unless ($release == 0 || $release eq 'all') {
    my $present = $SiteDefs::VERSION; 
    my $current = $present; 
    my $past = 0;
    if ($release < $present) { 
      $current = $release;
      $past = 1;
    }
    my $previous = $current - 1;
    if ($previous) {
      $self->{page}->menu->add_entry( $flag, 
                          'text' => "<< Release $previous",
                          'href' => "/$species/newsview?rel=$previous" );
	  }
    ## extra link forward if user has gone back to earlier news
    if ($past) {
      my $next = $current + 1;
      $self->{page}->menu->add_entry( $flag, 
                          'text' => ">> Release $next",
                          'href' => "/$species/newsview?rel=$next" );
      if ($current < ($present - 1)) {
      $self->{page}->menu->add_entry( $flag, 
                          'text' => "Current Release News",
                          'href' => "/$species/newsview?rel=$present" );
      }
    }
  }
}


1;

