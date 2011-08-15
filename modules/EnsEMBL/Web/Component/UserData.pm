# $Id$

package EnsEMBL::Web::Component::UserData;

use base qw(EnsEMBL::Web::Component);

use strict;

sub get_assemblies {
  ### Tries to identify coordinate system from file contents
  ### If on chromosomal coords and species has multiple assemblies,
  ### return assembly info
  
  my ($self, $species) = @_;
  my @assemblies = split(',', $self->hub->species_defs->get_config($species, 'CURRENT_ASSEMBLIES'));
  return \@assemblies;
}

sub add_file_format_dropdown {
  my ($self, $form, $limit) = @_;

  my @formats_to_display;
  if ($limit) {
    @formats_to_display = $limit eq 'remote' ? @{$self->hub->species_defs->REMOTE_FILE_FORMATS} 
                                                : @{$self->hub->species_defs->UPLOAD_FILE_FORMATS}; 
  }
  else {
    @formats_to_display = (@{$self->hub->species_defs->UPLOAD_FILE_FORMATS}, @{$self->hub->species_defs->REMOTE_FILE_FORMATS});
  }
 
  if (scalar @formats_to_display > 0) {
    my $values = [{'name' => '-- Choose --', 'value' => ''}];
    foreach my $f (sort {uc($a) cmp uc($b)} @formats_to_display) {
      push @$values, {'value' => uc($f), 'name' => $f};
    }
    $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'format',
      'label'   => "Data format",
      'values'  => $values,
      'select'  => 'select',
    );
  }

}

sub output_das_text {
  my ($self, $form, @sources) = @_;
  
  foreach (@sources) {
    $form->add_element(
      type    => 'Information',
      classes => [ 'no-bold' ],
      value   => sprintf('<strong>%s</strong><br />%s<br /><a href="%s">%3$s</a>', $_->label, $_->description, $_->homepage)
    );
  }
}

1;

