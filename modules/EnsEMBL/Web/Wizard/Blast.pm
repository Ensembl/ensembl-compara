package EnsEMBL::Web::Wizard::Blast;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Wizard;
use EnsEMBL::Web::Form;

our @ISA = qw(EnsEMBL::Web::Wizard);

sub _init {

  my ($self, $object) = @_;

  warn("Calling init in Blast wizard: $object");

  my @species_values = $object->get_species_values_for_dropdown;

  my %form_fields = (
    'prepare' => {
      'type'  => 'Information',
      'value' => 'You are now ready to start your Blast search. Clicking on \'Next\' will submit your job to the queue.',
    },
    'sequence' => {
      'type'  => 'Text',
      'value' => '',
      'label' => 'Sequence',
      'comment' => 'The nucelotide or amino acid sequence you want to search for'
    },
    'species' => {
      'type'    => 'DropDown',
      'select'  => 'select',
      'label'   => 'Species',
      'name'    => 'species_id',
      'comment' => 'Species databases to search against',
      'values'  => 'species_values',
      'value'   => '0'
    }
  );

  my %widgets = ();

  my %all_fields = (%form_fields, %widgets);

  my %all_nodes = (
    'blast_home' => {
      'form' => 1,
      'title' => 'Run a Blast search',
      'input_fields'  => [qw(sequence)],
      'progress_label' => "Sequence",
      'order' => '1'
    },
    'blast_ticket' => {
      'page' => 1,
      'button' => 'OK',
    },
    'blast_info' => {
      'form' => 1,
      'title' => 'Choose species',
      'input_fields'  => [qw(species)],
      'progress_label' => "Species",
      'order' => '2'
    },
    'blast_prepare' => {
      'form' => 1,
      'title' => 'Submit BLAST search',
      'input_fields'  => [qw(prepare)],
      'progress_label' => "Submit",
      'order' => '3'
    },
    'blast_submit' => {
      'form' => 1,
      'title' => 'Your Blast search has been submitted',
      'input_fields'  => [qw()],
    },
  );

  my $option = {
    'styles' => ['location'],
  };

  my $data = {
    'species_values' => \@species_values
  };

  return [$data, \%all_fields, \%all_nodes];
}

sub blast_home {

  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;

  my $node = "blast_home";
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;

}

sub blast_info {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;

  my $node = "blast_info";
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub blast_prepare {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;

  my $node = "blast_prepare";
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub blast_submit {
  my ($self, $object) = @_;

  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;

  my $node = "blast_submit";
  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');

  $wizard->add_widgets($node, $form, $object);
  $wizard->pass_fields($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);

  return $form;
}

sub blast_ticket {
  ## Displays a page containing ticket and queue information.
  ## blast_ticket is a dead end, as far as the Wizard goes.
}

1;
