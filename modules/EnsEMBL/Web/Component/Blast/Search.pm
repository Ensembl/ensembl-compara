package EnsEMBL::Web::Component::Blast::Search;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Blast);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  my $html = qq(<h2>$sitename Blast Search</h2>);

  my $form = EnsEMBL::Web::Form->new( 'blastsearch', "/Blast/Submit", 'get' );

  my @values;
  my @species = $object->species_defs->valid_species;
  foreach my $sp (sort @species) {
    (my $name = $sp) =~ s/_/ /;
    push @values, {'name'=>$name, 'value'=>$sp};
  }
  my $value = $object->species_defs->ENSEMBL_PRIMARY_SPECIES;

  $form->add_element(
    'type'    => 'DropDown',
    'select'  => 'select',
    'name'    => 'species',
    'label'   => 'Species',
    'values'  => \@values,
    'value'   => $value,
    'notes'   => ' Tip: Use the Ctrl button to select multiple species',
  );

  $form->add_element(
    'type'    => 'SubHeader',
    'value'   => 'Sequences, in FASTA or plain text:',
  );

  $form->add_element(
    'type'    => 'Text',
    'name'    => '_query_sequence',
    'label'   => 'Paste (max 30)',
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'name'    => 'method_noedit',
    'label'   => 'Search method',
    'value'   => 'BLASTN',
    #'value'   => 'BLAT',
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'method',
    'value'   => 'BLASTN',
    #'value'   => 'BLAT',
  );

  $form->add_element(
    'type'    => 'NoEdit',
    'name'    => 'db_noedit',
    'label'   => 'Database',
    'value'   => 'DNA - LATESTGP',
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'query',
    'value'   => 'dna',
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'database',
    'value'   => 'dna',
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'database_dna',
    'value'   => 'LATESTGP',
  );

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Run',
  );

  $html .= $form->render;

  $html .= '<p><a href="">Switch to advanced mode</a></p>',

  return $html;
}

1;
