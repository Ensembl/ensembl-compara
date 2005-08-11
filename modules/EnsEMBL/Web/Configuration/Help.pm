package EnsEMBL::Web::Configuration::Help;

use strict;
use EnsEMBL::Web::Configuration;
use Mail::Mailer;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub helpview {
  my $self = shift;
  my $object = $self->{object};

  $self->{'page'}->close->style = 'help';
  $self->{'page'}->close->URL   = "/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}";
  $self->{'page'}->close->kw    = $object->param('kw');
  $self->{'page'}->helplink->label  = 'Contact helpdesk';
  $self->{'page'}->helplink->action = 'form';
  $self->{'page'}->helplink->kw     = $object->param('kw');
  $self->{'page'}->helplink->ref    = $object->referer;

  $self->{'page'}->menu->add_block( '___', 'bulleted', 'Help with help!' );
  $self->{'page'}->menu->add_entry( '___', 'href' => $object->_help_URL( 'helpview' ), 'text' => 'General' ) ;
  $self->{'page'}->menu->add_entry( '___', 'href' => $object->_help_URL( 'helpview#searching' ), 'text' => 'Full text search' );
  $self->set_title( 'Ensembl HelpView' );
  my $include_form = 1;
  if( $object->param( 'action' ) ) { ## Actually this is the old helpdesk page...
    if( $object->param( 'action' ) eq 'thank_you' ) {
      my $panel = $self->new_panel( '',
        'code'    => 'panel',
        'caption' => "Thanks for your correspondence",
        'object'  => $object
      );
      $panel->add_components(qw(thank_you EnsEMBL::Web::Component::Help::form_thankyou));
      $self->add_panel( $panel );
      $include_form = 0;
    } elsif( $object->param( 'action' ) eq 'submit' ) {
      $object->send_email;
      $include_form = 0;
    }
  }
  if( $include_form && $object->param('action') ne 'form' ) {
    if( @{$object->results} ) {
      warn ">HERE";
      if( @{$object->results} == 1 ) {
        my $panel = $self->new_panel( '',
          'code'    => 'panel',
          'caption' => $object->results->[0]->{'title'},
          'object'  => $object
        );
        $panel->add_components(qw(single_match EnsEMBL::Web::Component::Help::single_match));
        $self->add_panel( $panel );
      } else {
        my $panel = $self->new_panel( '',
          'code'    => 'panel',
          'caption' => qq(Search for "@{[$object->param('kw')]}"),
          'object'  => $object
        );
        $panel->add_components(qw(multi_match EnsEMBL::Web::Component::Help::multi_match));
        $self->add_panel( $panel );
      }
      $include_form = 0;
    } else {
      if( $object->param( 'kw' ) ) {
        my $panel = $self->new_panel( '',
          'code'    => 'panel',
          'caption' => qq(No such help page),
          'object'  => $object
        );
        $panel->add_components(qw(single_match_failure EnsEMBL::Web::Component::Help::single_match_failure));
        $self->add_panel( $panel );
      } else {
        my $panel = $self->new_panel( '',
          'code'    => 'panel',
          'caption' => qq(Ensembl help),
          'object'  => $object
        );
        $panel->add_components(qw(first_page EnsEMBL::Web::Component::Help::first_page));
        $self->add_panel( $panel );
      }
    }
  }
  if( $include_form ) {
    my $panel2 = $self->new_panel( '',
      'code'    => 'form',
      'caption' => 'Getting further help',
      'object'  => $object
    );
    $self->add_form( $panel2, qw(help_form EnsEMBL::Web::Component::Help::help_form_form));
    $panel2->add_components(qw(help_form EnsEMBL::Web::Component::Help::help_form));
    $self->add_panel( $panel2 );
  }
  $self->{page}->title->set( 'Help!' );
}

sub context_menu {
  my $self = shift;
  my $object = $self->{object};
  my $display_length = 34; #no of characters of the title that are to be displayed
  my $focus = $object->param('kw'); # get the current entry
  $focus =~ s/(.*)\#/$1/;

  my @result_array = @{ $object->Obj->{'index'} || [] };
  foreach my $row ( @result_array ) {
    (my $name = $row->{'title'} ) =~ s/^(.{50})...+/\1.../;
    $self->add_block( lc($row->{'category'}), 'bulleted', $row->{'category'} );
    my %hash= ( 'text' => $name );
       $hash{ 'title' } =  $row->{'title'} unless $name eq $row->{'title'};
    if( $row->{'keyword'} eq $focus ) {
      $hash{ 'text'  } =  "$name";
    } else {
      $hash{ 'href'  } =  $object->_help_URL( $row->{'keyword'} );
    }
    $self->add_entry( lc($row->{'category'}), %hash );
  }
}

1;
