# $Id$

package EnsEMBL::Web::Component::UserData::SelectFeatures;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  return 'Select File to Upload';
}

sub content {
  my $self            = shift;
  my $hub             = $self->hub;
  my $session         = $hub->session;
  my $species_defs    = $hub->species_defs;
  my $sitename        = $species_defs->ENSEMBL_SITETYPE;
  my $species         = $hub->species;
  my $current_species = $hub->data_species;
  my $html;

  ## Get assembly info
  my $form = $self->modal_form('select', $hub->species_path($current_species) . "/UserData/CheckConvert");
  $form->add_notes({'heading' => 'Tips',
  'text' => qq(<p class="space-below">Map your data to the current assembly. Accepted file formats: GFF, GTF, BED, PSL</p>
<p class="space-below">N.B. Export is currently in GFF only</p>
<p>For large data sets, you may find it more efficient to use our <a href="ftp://ftp.ensembl.org/pub/misc-scripts/Assembly_mapper_1.0/">ready-made converter script</a>.</p>)
  });
  my $subheader = 'Upload file';

  ## Species now set automatically for the page you are on
  my @species;
  foreach my $sp ($species_defs->valid_species) {
    push @species, {'value' => $sp, 'name' => $species_defs->species_label($sp, 1)};
  }
  @species = sort {$a->{'name'} cmp $b->{'name'}} @species;

  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'species',
      'label'   => "Species",
      'values'  => \@species,
      'value'   => $current_species,
      'select'  => 'select',
  );

  ## Which conversion?
  my @mappings = reverse sort @{$species_defs->ASSEMBLY_MAPPINGS};
  my (@forward, @backward);
  foreach my $string (@mappings) {
    my ($to, $from) = split('#', $string);
    push @forward, {'name' => $from.' -> '.$to, 'value' => $from.':'.$to};
    push @backward, {'name' => $to.' -> '.$from, 'value' => $to.':'.$from};
  }
  my @values = (@forward, @backward);
  $form->add_element(
    'type'    => 'DropDown',
    'name'    => 'conversion',
    'label'   => "Assembly/coordinates to convert",
    'values'  => \@values,
    'select'   => 'select',
  );

  ## Check for uploaded data for this species
  my $user = $hub->user;
  if ($user) {
    my (@data, @temp);
    foreach my $upload ($user->uploads) {
      next unless $upload->species eq $species;
      push @data, $upload; 
    } 
    foreach my $upload ($session->get_data('type' => 'upload')) {
      next unless $upload->{'species'} eq $species;
      push @data, $upload;
    } 
    foreach my $url ($user->urls) {
      next unless $url->species eq $species;
      push @data, $url;
    } 
    foreach my $url ($session->get_data('type' => 'url')) {
      next unless $url->{'species'} eq $species;
      push @data, $url;
    } 
    
    if (@data) {
      $form->add_element('type' => 'SubHeader',
        'value' => 'Select existing upload(s)',
      );
      foreach my $file (@data) {
        my ($name, $id, $species);
        if (ref ($file) =~ /Record/) {
          my $type = $file->type;
          $name = $file->name;
          $id   = 'user-'.$type.'-'.$file->id; 
        }
        else {
          my $type = $file->{'type'};
          $name = $file->{'name'};
          $id   = 'temp-'.$type.'-'.$file->{'code'};
        }
        $form->add_element(
          'type'    => 'CheckBox',
          'name'    => 'convert_file',
          'label'   => $name,
          'value'   => $id.':'.$name,
        );
      }
      $subheader = 'Or upload new file';
    }
  }

  $form->add_element('type' => 'SubHeader', 'value' => $subheader);

  $form->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );

  $form->add_element( type => 'Text', name => 'text', label => 'Paste file' );
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'URL',  name => 'url',  label => 'or provide file URL', size => 30 );

  $html .= $form->render;
  return $html;
}

1;
