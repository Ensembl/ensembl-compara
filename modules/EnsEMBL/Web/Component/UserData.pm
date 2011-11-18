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

  my @formats;
  if ($limit) {
    @formats = $limit eq 'remote' ? @{$self->hub->species_defs->REMOTE_FILE_FORMATS} 
                                                : @{$self->hub->species_defs->UPLOAD_FILE_FORMATS}; 
  }
  else {
    @formats = (@{$self->hub->species_defs->UPLOAD_FILE_FORMATS}, @{$self->hub->species_defs->REMOTE_FILE_FORMATS});
  }
  my $format_info = $self->hub->species_defs->DATA_FORMAT_INFO;
 
  if (scalar @formats > 0) {
    my $values = [{'name' => '-- Choose --', 'value' => ''}];
    foreach my $f (sort {$a cmp $b} @formats) {
      push @$values, {'value' => uc($f), 'name' => $format_info->{$f}{'label'}};
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

