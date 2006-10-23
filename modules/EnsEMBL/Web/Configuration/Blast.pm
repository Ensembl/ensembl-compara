package EnsEMBL::Web::Configuration::Blast;

use strict;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Wizard::Blast;

our @ISA = qw( EnsEMBL::Web::Configuration );

#-----------------------------------------------------------------------

sub blastview {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = EnsEMBL::Web::Wizard::Blast->new($object);
  $wizard->add_nodes([qw(blast_home blast_info blast_ticket blast_prepare blast_submit)]);
  $wizard->default_node('blast_home');
  $wizard->chain_nodes([
          ['blast_home'=>'blast_info'],
          ['blast_info'=>'blast_prepare'],
          ['blast_prepare'=>'blast_submit'],
  ]);

  $self->add_wizard($wizard);
  my $here = $wizard->current_node($object);
  if ($here eq 'blast_submit') {
    warn("Adding Ajax javascript files");
    $self->{page}->javascript->add_source( "/js/prototype.js" );
    $self->{page}->javascript->add_source( "/js/blastview.js" );
  }
  $self->wizard_panel('Blastview');
  warn("Configured Blastview for $here");
}

sub searchview {
  my $self   = shift;
  my $object = $self->{'object'};
  my $ticket = $object->param('ticket');

  ## TODO: Change the add_body_attr call below to take settings from
  ## global config

  $self->{page}->javascript->add_source( "/js/prototype-1.4.0.js" );
  $self->{page}->javascript->add_source( "/js/blastview.js" );
  #$self->{page}->add_body_attr( 'onload' => "javascript:start_periodic_updates(10000, 'blast_queue_ticket', '$ticket', 'update_status')");

  my $panel = $self->new_panel('Image', 'code' => 'info', 'object' => $object);
  if ($panel) {
    $panel->add_components(qw(show_news EnsEMBL::Web::Component::Blast::searchview));
  }

  $self->{page}->content->add_panel($panel);

}

sub context_menu {
  my $self   = shift;
  my $object = $self->{'object'};
  my $wizard = $self->{wizard};
  if ($wizard) {
    my $here = $self->{wizard}->current_node($object);
    $object->request->update($object);
    if ($here ne 'blast_home' && $here ne 'blast_ticket') {
      $self->{page}->menu->add_block( $here, 'bulleted', "Blast search" );
      $self->add_entry($here, 
        'code' => 'blast_info_sequence_type',
        'text' => $object->request->type,
        'title' => "Sequence information",
        'icon' => '/img/infoicon.gif',
      );

      if (!$object->request->is_ticket) {  
        $self->add_entry($here, 
          'code' => 'blast_info_sequence_count',
          'text' => $object->request->sequence_length . " " . $object->request->units,
          'title' => "Sequence information",
          'icon' => '/img/infoicon.gif',
        );
      } 

      if ($here eq 'blast_prepare' || $here eq 'blast_submit') { 
        if ($object->request->species) {
          $self->add_entry($here, 
            'code' => 'blast_info_species',
            'text' => $object->species_for_id($object->request->species),
            'title' => "Species",
            'icon' => '/img/infoicon.gif',
          );
        } else {
          $self->add_entry($here, 
            'code' => 'blast_info_species',
            'text' => 'All species', 
            'title' => "Species",
            'icon' => '/img/infoicon.gif',
          );
        }
      }
      $self->add_entry($here,
        'code' => 'blast_info',
        'text' => 'Start again',
        'href' => 'blastview',
        'title' => "Restart your Blast search (all settings will be reset)",
       );
    } # end of wizard check
   
   }
}

sub context_location {
}

1;
