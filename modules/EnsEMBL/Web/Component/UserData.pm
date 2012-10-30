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
  my ($self, $form, $limit, $js_enabled) = @_;

  my $sd              = $self->hub->species_defs;
  my @remote_formats  = $limit && $limit eq 'upload' ? () : @{$sd->REMOTE_FILE_FORMATS};
  my @upload_formats  = $limit && $limit eq 'remote' ? () : @{$sd->UPLOAD_FILE_FORMATS};
  my $format_info     = $sd->DATA_FORMAT_INFO;
  my %format_type     = (map({$_ => 'remote'} @remote_formats), map({$_ => 'upload'} @upload_formats));

  if (scalar @remote_formats || scalar @upload_formats) {
    my $values = [
      {'caption' => '-- Choose --', 'value' => ''},
      map { 'value' => uc($_), 'caption' => $format_info->{$_}{'label'}, $js_enabled ? ('class' => "_stt__$format_type{$_} _action_$format_type{$_}") : () }, sort (@remote_formats, @upload_formats)
    ];
    $form->add_field({
      'type'    => 'dropdown',
      'name'    => 'format',
      'label'   => 'Data format',
      'values'  => $values,
      'notes'   => '<a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a>',
      $js_enabled ? ( 'class' => '_stt _action' ) : ()
    });
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

