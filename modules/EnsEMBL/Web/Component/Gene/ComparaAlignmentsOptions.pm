package EnsEMBL::Web::Component::Gene::ComparaAlignmentsOptions;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;
  my $hash = $object->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}||{};

#  $object->param("RGselect",'171'); #hack to get script working
#  $object->param("RGselect",'NONE'); #hack to get script working


# From release to release the alignment ids change so we need to check that the passed id is still valid.

# Need to collapse these panels
  my $url = $object->_url({'otherspecies'=>undef},1);
  use Data::Dumper;warn Dumper($url);
  my $form = EnsEMBL::Web::Form->new( 'change_sp', $url->[0], 'get', 'nonstd check' );
  $form->add_hidden( $url->[1] );

  my @alignment_types;
  foreach my $row_key (
      grep { $hash->{$_}{'class'} !~ /pairwise/ } keys %$hash
  ) {
      my $row = $hash->{$row_key};
      next unless $row->{'species'}{$species};
      push @alignment_types, $row->{'name'};
      warn "Options for ".$row->{'name'};
      $form->add_element(
          'type'     => 'CheckBox',
	  'label' => $row->{'name'},
          'name'     => $row->{'name'},
          'value'    => 'yes', 'raw' => 1
      );
  }
  foreach my $row_key (
      grep { $hash->{$_}{'class'} =~ /pairwise/ } keys %$hash
  ) {
      my $row = $hash->{$row_key};
      next unless $row->{'species'}{$species};
      $form->add_element(
          'type'     => 'CheckBox',
	  'label'    => 'Pairwise Alignments',
          'name'     => 'Pairwise Alignments',
          'value'    => 'yes', 'raw' => 1
      );
      push @alignment_types, 'Pairwise Alignments';
      last;
  }

  $form->add_element(
      'type'     => 'DropDownAndSubmit',
      'select'   => 'select',
      'style'    => 'narrow',
      'on_change' => 'submit',
      'name'     => 'otherspecies',
      'label'    => 'Change Alignment Type',
      'values'   => \@alignment_types,
      'value'    => $alignment_types[0],
      'button_value' => 'Go'
  );
  return '<div class="center">'.$form->render.'</div>';
}

1;
