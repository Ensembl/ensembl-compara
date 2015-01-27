=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
  my @remote_formats  = $limit && $limit eq 'upload' ? () : @{$sd->multi_val('REMOTE_FILE_FORMATS')||[]};
  my @upload_formats  = $limit && $limit eq 'remote' ? () : @{$sd->multi_val('UPLOAD_FILE_FORMATS')||[]};
  my $format_info     = $sd->multi_val('DATA_FORMAT_INFO');
  my %format_type     = (map({$_ => 'remote'} @remote_formats), map({$_ => 'upload'} @upload_formats));
  ## Override defaults for datahub, which is a special case
  $format_type{'datahub'} = 'datahub';

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

